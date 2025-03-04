#!/usr/bin/env python3
"""
Script to generate SQL INSERT statements for adding top albums
from Spotify API to the Chinook database for a specified date range.
"""

import requests
import json
import base64
import argparse
import time
from datetime import datetime
import random
import os
from typing import List, Dict, Tuple, Any, Optional, Generator
import logging
from pathlib import Path
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Load environment variables for API credentials
load_dotenv()

# Constants
BATCH_SIZE = 1000
DEFAULT_ALBUMS_PER_YEAR = 20

# Type aliases for improved readability
AlbumInfo = Tuple[str, str, int, str, List[Tuple[str, int, str]]]
TrackInfo = Tuple[str, int, str]


class SpotifyClient:
    """Handles Spotify API authentication and requests with proper rate limiting"""
    
    def __init__(self):
        """Initialize the Spotify client with credentials from environment"""
        self.client_id = os.getenv("SPOTIFY_CLIENT_ID")
        self.client_secret = os.getenv("SPOTIFY_CLIENT_SECRET")
        
        if not self.client_id or not self.client_secret:
            raise ValueError(
                "Spotify API credentials not found. Set SPOTIFY_CLIENT_ID and "
                "SPOTIFY_CLIENT_SECRET as environment variables or in a .env file."
            )
        
        self.token = self._get_token()
        self.headers = self._create_headers()
        self.request_count = 0
        self.last_request_time = 0
    
    def _get_token(self) -> str:
        """Get access token for Spotify API with error handling"""
        auth_string = f"{self.client_id}:{self.client_secret}"
        auth_bytes = auth_string.encode("utf-8")
        auth_base64 = base64.b64encode(auth_bytes).decode("utf-8")
        
        url = "https://accounts.spotify.com/api/token"
        headers = {
            "Authorization": f"Basic {auth_base64}",
            "Content-Type": "application/x-www-form-urlencoded"
        }
        data = {"grant_type": "client_credentials"}
        
        try:
            response = requests.post(url, headers=headers, data=data)
            response.raise_for_status()
            json_result = response.json()
            token = json_result.get("access_token")
            if not token:
                raise ValueError("No access token in Spotify API response")
            return token
        except Exception as e:
            logger.error(f"Error getting Spotify token: {e}")
            raise
    
    def _create_headers(self) -> Dict[str, str]:
        """Create headers for Spotify API requests"""
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
    
    def _rate_limit(self) -> None:
        """Implement rate limiting to avoid hitting Spotify API limits"""
        self.request_count += 1
        
        # Basic rate limiting: max 10 requests per second
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        
        if self.request_count > 10 and time_since_last < 1.0:
            sleep_time = 1.0 - time_since_last
            time.sleep(sleep_time)
            # Reset counter after sleeping
            self.request_count = 0
        
        # If it's been more than a second since the last request, reset counter
        if time_since_last >= 1.0:
            self.request_count = 0
        
        self.last_request_time = time.time()
    
    def make_request(self, url: str, params: Optional[Dict] = None) -> Dict:
        """Make a rate-limited request to the Spotify API with error handling and retries"""
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            # Apply rate limiting
            self._rate_limit()
            
            try:
                response = requests.get(url, headers=self.headers, params=params)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.HTTPError as e:
                # Handle specific error codes
                if e.response.status_code == 429:  # Too Many Requests
                    retry_after = int(e.response.headers.get('Retry-After', 1))
                    logger.warning(f"Rate limited by Spotify. Waiting {retry_after} seconds.")
                    time.sleep(retry_after)
                    retry_count += 1
                    continue
                elif e.response.status_code == 401:  # Unauthorized - token expired
                    logger.info("Token expired. Getting new token.")
                    self.token = self._get_token()
                    self.headers = self._create_headers()
                    retry_count += 1
                    continue
                else:
                    logger.error(f"HTTP error: {e}")
                    raise
            except Exception as e:
                logger.error(f"Error making request to {url}: {e}")
                retry_count += 1
                if retry_count < max_retries:
                    wait_time = 2 ** retry_count  # Exponential backoff
                    logger.info(f"Retrying in {wait_time} seconds...")
                    time.sleep(wait_time)
                else:
                    logger.error(f"Failed after {max_retries} retries")
                    raise
        
        raise Exception(f"Failed to get response from {url} after {max_retries} retries")


class ChinookGenreMapper:
    """Maps Spotify genres to Chinook database genre IDs"""
    
    def __init__(self):
        """Initialize with genre mappings"""
        self.genre_mapping = {
            "rock": "Rock",
            "metal": "Metal",
            "hard rock": "Rock",
            "punk": "Alternative & Punk",
            "alternative": "Alternative",
            "indie": "Alternative",
            "pop": "Pop",
            "hip hop": "Hip Hop/Rap",
            "rap": "Hip Hop/Rap",
            "trap": "Hip Hop/Rap",
            "r&b": "R&B/Soul",
            "soul": "R&B/Soul",
            "jazz": "Jazz",
            "blues": "Blues",
            "country": "Country",
            "folk": "Folk",
            "classical": "Classical",
            "edm": "Electronica/Dance",
            "electronic": "Electronica/Dance",
            "dance": "Electronica/Dance",
            "techno": "Electronica/Dance",
            "house": "Electronica/Dance",
            "latin": "Latin",
            "reggae": "Reggae",
            "reggaeton": "Latin",
            "world": "World",
        }
        
        self.genre_id_map = {
            "Rock": 1,
            "Jazz": 2,
            "Metal": 3,
            "Alternative & Punk": 4,
            "Rock And Roll": 5,
            "Blues": 6,
            "Latin": 7,
            "Reggae": 8,
            "Pop": 9,
            "Soundtrack": 10,
            "Bossa Nova": 11,
            "Easy Listening": 12,
            "Heavy Metal": 13,
            "R&B/Soul": 14,
            "Electronica/Dance": 15,
            "World": 16,
            "Hip Hop/Rap": 17,
            "Science Fiction": 18,
            "TV Shows": 19,
            "Sci Fi & Fantasy": 20,
            "Drama": 21,
            "Comedy": 22,
            "Alternative": 23,
            "Classical": 24,
            "Opera": 25
        }
    
    def map_spotify_genre_to_chinook(self, spotify_genre: str) -> str:
        """Map a Spotify genre to a Chinook genre name"""
        # Convert to lowercase for matching
        spotify_genre = spotify_genre.lower()
        
        # Check for matches
        for key, value in self.genre_mapping.items():
            if key in spotify_genre:
                return value
        
        # Default to Rock if no match
        return "Rock"
    
    def get_genre_id(self, genre_name: str) -> int:
        """Get Chinook genre ID from genre name"""
        return self.genre_id_map.get(genre_name, 1)  # Default to Rock (1) if not found


class SpotifyAlbumFetcher:
    """Fetches album data from Spotify API"""
    
    def __init__(self, spotify_client: SpotifyClient, genre_mapper: ChinookGenreMapper):
        """Initialize with required dependencies"""
        self.spotify = spotify_client
        self.genre_mapper = genre_mapper
    
    def fetch_albums_by_year_range(
        self, start_year: int, end_year: int, albums_per_year: int
    ) -> List[AlbumInfo]:
        """Fetch albums for a range of years"""
        all_albums = []
        current_year = datetime.now().year
        
        for year in range(start_year, min(end_year + 1, current_year + 1)):
            logger.info(f"Fetching albums for {year}...")
            year_albums = self._fetch_albums_for_year(year, albums_per_year)
            all_albums.extend(year_albums)
            logger.info(f"Added {len(year_albums)} albums for {year}")
        
        return all_albums
    
    def _fetch_albums_for_year(self, year: int, max_albums: int) -> List[AlbumInfo]:
        """Fetch albums for a specific year"""
        # Search for albums from the specified year
        search_url = "https://api.spotify.com/v1/search"
        query = f"year:{year}"
        params = {
            "q": query,
            "type": "album",
            "limit": min(max_albums, 50),  # Spotify's max limit is 50
            "market": "US"
        }
        
        data = self.spotify.make_request(search_url, params)
        year_albums = []
        
        if "albums" in data and "items" in data["albums"]:
            # Process each album
            for album in data["albums"]["items"][:max_albums]:
                album_data = self._fetch_album_details(album["id"])
                
                if album_data:
                    # Check if the release year matches the target year
                    release_date = album_data.get("release_date", f"{year}-01-01")
                    release_year = int(release_date.split("-")[0])
                    
                    if release_year == year:
                        album_info = self._process_album_data(album_data, year)
                        if album_info:
                            year_albums.append(album_info)
                
                # Stop if we've reached the desired count
                if len(year_albums) >= max_albums:
                    break
        
        return year_albums[:max_albums]
    
    def _fetch_album_details(self, album_id: str) -> Optional[Dict]:
        """Fetch detailed album information"""
        album_url = f"https://api.spotify.com/v1/albums/{album_id}"
        return self.spotify.make_request(album_url)
    
    def _fetch_artist_details(self, artist_id: str) -> Optional[Dict]:
        """Fetch detailed artist information"""
        artist_url = f"https://api.spotify.com/v1/artists/{artist_id}"
        return self.spotify.make_request(artist_url)
    
    def _process_album_data(self, album_data: Dict, year: int) -> Optional[AlbumInfo]:
        """Process album data to extract required information"""
        if "name" not in album_data or "artists" not in album_data:
            return None
        
        # Extract basic album info
        artist_name = album_data["artists"][0]["name"]
        album_name = album_data["name"]
        
        # Get genre from artist
        artist_id = album_data["artists"][0]["id"]
        artist_data = self._fetch_artist_details(artist_id)
        
        genre = "Unknown"
        if artist_data and "genres" in artist_data and len(artist_data["genres"]) > 0:
            spotify_genre = artist_data["genres"][0]
            genre = self.genre_mapper.map_spotify_genre_to_chinook(spotify_genre)
        
        # Process tracks
        tracks = []
        if "tracks" in album_data and "items" in album_data["tracks"]:
            for track in album_data["tracks"]["items"]:
                track_name = track["name"]
                duration_ms = track["duration_ms"]
                composer = artist_name  # Default composer to artist
                tracks.append((track_name, duration_ms, composer))
        
        return (artist_name, album_name, year, genre, tracks)


class SQLGenerator:
    """Generates SQL INSERT statements for Chinook database"""
    
    def __init__(self, genre_mapper: ChinookGenreMapper, max_rows_per_batch: int = BATCH_SIZE):
        """Initialize with dependencies and configuration"""
        self.genre_mapper = genre_mapper
        self.max_rows_per_batch = max_rows_per_batch
    
    @staticmethod
    def escape_sql_string(s: Optional[str]) -> str:
        """Escape single quotes for SQL insertion"""
        if s is None:
            return ""
        return s.replace("'", "''")
    
    @staticmethod
    def chunk_list(input_list: list, chunk_size: int) -> Generator:
        """Split a list into smaller chunks"""
        for i in range(0, len(input_list), chunk_size):
            yield input_list[i:i + chunk_size]
    
    def generate_sql(
        self, 
        albums: List[AlbumInfo], 
        max_artist_id: int, 
        max_album_id: int, 
        max_track_id: int
    ) -> str:
        """Generate SQL for inserting albums, artists, and tracks"""
        next_artist_id = max_artist_id + 1
        next_album_id = max_album_id + 1
        next_track_id = max_track_id + 1
        
        # Track artist IDs to avoid duplicates
        artist_ids = {}
        
        # Prepare SQL statements
        sql_parts = []
        sql_parts.append(self._generate_header())
        
        # Generate artist SQL
        new_artists = []
        for album_data in albums:
            artist_name, _, _, _, _ = album_data
            artist_name = self.escape_sql_string(artist_name)
            
            # Skip if we already have this artist
            if artist_name in artist_ids:
                continue
            
            # Add artist to tracking and SQL list
            artist_ids[artist_name] = next_artist_id
            new_artists.append((next_artist_id, artist_name))
            next_artist_id += 1
        
        # Add artists with proper SQL format
        if new_artists:
            artist_sql = self._generate_artist_sql(new_artists)
            sql_parts.append(artist_sql)
        
        # Generate album SQL
        album_map = {}  # Store album info for track creation
        new_albums = []
        
        for album_data in albums:
            artist_name, album_name, release_year, genre, tracks = album_data
            
            # Escape strings for SQL
            artist_name = self.escape_sql_string(artist_name)
            album_name = self.escape_sql_string(album_name)
            
            # Get artist ID from our batch
            artist_id = artist_ids.get(artist_name)
            
            if artist_id:
                # Include ReleaseYear in the album data
                new_albums.append((next_album_id, album_name, artist_id, release_year))
                album_map[next_album_id] = (album_name, artist_id, genre, tracks)
                next_album_id += 1
        
        # Add albums with proper SQL format
        if new_albums:
            album_sql = self._generate_album_sql(new_albums)
            sql_parts.append(album_sql)
        
        # Generate track SQL
        new_tracks = []
        
        # List of potential media types from Chinook
        media_types = [1, 2, 4, 5]  # MPEG, Protected AAC, Purchased AAC, AAC
        media_type_weights = [10, 20, 40, 30]  # Weights favoring modern formats
        
        for album_id, album_info in album_map.items():
            album_name, artist_id, genre, tracks = album_info
            
            # Get genre ID
            genre_id = self.genre_mapper.get_genre_id(genre)
            
            # Process each track
            for track_data in tracks:
                track_name, duration_ms, composer = track_data
                
                # Escape strings for SQL
                track_name = self.escape_sql_string(track_name)
                composer = self.escape_sql_string(composer)
                
                # Use weighted media type selection
                media_type_id = random.choices(media_types, weights=media_type_weights)[0]
                
                # Generate bytes size based on duration
                bytes_size = duration_ms * random.randint(35, 45)
                
                # Standard pricing with minor variation
                unit_price = random.choice([0.99, 1.29] if random.random() < 0.2 else [0.99])
                
                new_tracks.append((
                    next_track_id, track_name, album_id, media_type_id,
                    genre_id, composer, duration_ms, bytes_size, unit_price
                ))
                next_track_id += 1
        
        # Add tracks with proper SQL format
        if new_tracks:
            track_sql = self._generate_track_sql(new_tracks)
            sql_parts.append(track_sql)
        
        return "\n".join(sql_parts)
    
    def _generate_header(self) -> str:
        """Generate SQL file header"""
        return "\n".join([
            "/*******************************************************************************",
            "   Chinook Database - Album Import",
            "   Description: Adds new albums, artists, and tracks from Spotify API.",
            f"   Date Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "********************************************************************************/",
            ""
        ])
    
    def _generate_artist_sql(self, artists: List[Tuple[int, str]]) -> str:
        """Generate SQL for artist insertions"""
        sql_parts = []
        
        # Split artists into batches
        artist_batches = list(self.chunk_list(artists, self.max_rows_per_batch))
        
        for i, artist_batch in enumerate(artist_batches):
            sql_parts.append(f"-- Artist insert batch {i+1} of {len(artist_batches)}")
            sql_parts.append("INSERT INTO Artist (ArtistId, Name) VALUES")
            
            artist_values = []
            for artist_id, artist_name in artist_batch:
                artist_values.append(f"    ({artist_id}, '{artist_name}')")
            
            sql_parts.append(",\n".join(artist_values) + ";")
            sql_parts.append("")
        
        return "\n".join(sql_parts)
    
    def _generate_album_sql(self, albums: List[Tuple[int, str, int, int]]) -> str:
        """Generate SQL for album insertions"""
        sql_parts = []
        
        # Split albums into batches
        album_batches = list(self.chunk_list(albums, self.max_rows_per_batch))
        
        for i, album_batch in enumerate(album_batches):
            sql_parts.append(f"-- Album insert batch {i+1} of {len(album_batches)}")
            sql_parts.append("INSERT INTO Album (AlbumId, Title, ArtistId, ReleaseYear) VALUES")
            
            album_values = []
            for album_id, title, artist_id, release_year in album_batch:
                album_values.append(f"    ({album_id}, '{title}', {artist_id}, {release_year})")
            
            sql_parts.append(",\n".join(album_values) + ";")
            sql_parts.append("")
        
        return "\n".join(sql_parts)
    
    def _generate_track_sql(self, tracks: List[Tuple]) -> str:
        """Generate SQL for track insertions"""
        sql_parts = []
        
        # Split tracks into batches
        track_batches = list(self.chunk_list(tracks, self.max_rows_per_batch))
        
        for i, track_batch in enumerate(track_batches):
            sql_parts.append(f"-- Track insert batch {i+1} of {len(track_batches)}")
            sql_parts.append("INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES")
            
            track_values = []
            for track in track_batch:
                track_id, name, album_id, media_type_id, genre_id, composer, milliseconds, bytes_size, unit_price = track
                track_values.append(
                    f"    ({track_id}, '{name}', {album_id}, {media_type_id}, {genre_id}, "
                    f"'{composer}', {milliseconds}, {bytes_size}, {unit_price})"
                )
            
            sql_parts.append(",\n".join(track_values) + ";")
            sql_parts.append("")
        
        return "\n".join(sql_parts)


def get_max_ids() -> Tuple[int, int, int]:
    """Prompt user for current maximum IDs from the database"""
    print("Please enter the current maximum IDs from your database:")
    print("Run this SQL query to get them:")
    print("SELECT")
    print("    (SELECT MAX(ArtistId) FROM Artist) AS MaxArtistId,")
    print("    (SELECT MAX(AlbumId) FROM Album) AS MaxAlbumId,")
    print("    (SELECT MAX(TrackId) FROM Track) AS MaxTrackId;")
    print("")
    
    try:
        max_artist_id = int(input("Enter current max ArtistId: ").strip())
        max_album_id = int(input("Enter current max AlbumId: ").strip())
        max_track_id = int(input("Enter current max TrackId: ").strip())
        
        logger.info(f"Using starting IDs - Artist: {max_artist_id + 1}, Album: {max_album_id + 1}, Track: {max_track_id + 1}")
        return max_artist_id, max_album_id, max_track_id
    except ValueError:
        logger.error("Invalid input. Please enter valid integer values for IDs.")
        raise ValueError("Invalid input for database IDs")


def validate_args(args: argparse.Namespace) -> None:
    """Validate command line arguments"""
    current_year = datetime.now().year
    
    if args.start_year > args.end_year:
        raise ValueError("Start year must be less than or equal to end year.")
    
    if args.count < 1:
        raise ValueError("Album count must be at least 1.")
    
    if args.max_rows < 1:
        raise ValueError("Maximum rows per INSERT must be at least 1.")
    
    # Just warn if end year is in the future
    if args.end_year > current_year:
        logger.warning(f"End year {args.end_year} is in the future. Will only fetch albums up to {current_year}.")


def main():
    """Main function to run the script"""
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description="Import albums from Spotify API to Chinook database."
    )
    parser.add_argument(
        "--start-year", type=int, required=True, 
        help="Start year for album search"
    )
    parser.add_argument(
        "--end-year", type=int, required=True, 
        help="End year for album search"
    )
    parser.add_argument(
        "--count", type=int, default=DEFAULT_ALBUMS_PER_YEAR, 
        help=f"Number of albums per year (default: {DEFAULT_ALBUMS_PER_YEAR})"
    )
    parser.add_argument(
        "--output", type=str, default="add_albums.sql", 
        help="Output SQL file name"
    )
    parser.add_argument(
        "--max-rows", type=int, default=BATCH_SIZE, 
        help=f"Maximum rows per INSERT statement (default: {BATCH_SIZE})"
    )
    args = parser.parse_args()
    
    try:
        # Validate arguments
        validate_args(args)
        
        # Get current max IDs from database
        max_artist_id, max_album_id, max_track_id = get_max_ids()
        
        # Initialize components
        spotify_client = SpotifyClient()
        genre_mapper = ChinookGenreMapper()
        album_fetcher = SpotifyAlbumFetcher(spotify_client, genre_mapper)
        sql_generator = SQLGenerator(genre_mapper, args.max_rows)
        
        # Fetch albums
        logger.info(f"Searching for {args.count} albums per year from {args.start_year} to {args.end_year}...")
        albums = album_fetcher.fetch_albums_by_year_range(args.start_year, args.end_year, args.count)
        logger.info(f"Found {len(albums)} albums to add")
        
        # Generate SQL
        sql = sql_generator.generate_sql(albums, max_artist_id, max_album_id, max_track_id)
        
        # Write SQL to file
        output_path = Path(args.output)
        output_path.write_text(sql)
        
        logger.info(f"SQL file generated: {output_path.absolute()}")
        print("\nRun this SQL file with your Apache Ignite SQL tool to add the albums to your database.")
        
    except Exception as e:
        logger.error(f"Error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())