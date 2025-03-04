import requests
import base64
from urllib.parse import urlencode


def get_access_token(client_id, client_secret):
    """
    Get Spotify API access token using client credentials flow

    Args:
        client_id (str): Your Spotify API client ID
        client_secret (str): Your Spotify API client secret

    Returns:
        str: Access token
    """
    auth_string = f"{client_id}:{client_secret}"
    auth_bytes = auth_string.encode("utf-8")
    auth_base64 = base64.b64encode(auth_bytes).decode("utf-8")

    url = "https://accounts.spotify.com/api/token"
    headers = {
        "Authorization": f"Basic {auth_base64}",
        "Content-Type": "application/x-www-form-urlencoded",
    }
    data = {"grant_type": "client_credentials"}

    response = requests.post(url, headers=headers, data=data)
    json_result = response.json()

    if response.status_code != 200:
        raise Exception(
            f"Failed to get access token: {json_result.get('error_description', 'Unknown error')}"
        )

    return json_result["access_token"]


def get_top_albums_by_year(
    year, limit=50, client_id=None, client_secret=None, access_token=None, market="US"
):
    """
    Get top albums for a specific year based on Spotify popularity

    Args:
        year (int): The year to get top albums for
        limit (int): Maximum number of albums to return
        client_id (str): Your Spotify API client ID
        client_secret (str): Your Spotify API client secret
        access_token (str, optional): Pre-existing access token
        market (str): Country code for market-specific results

    Returns:
        list: Sorted list of album dictionaries by popularity
    """
    # Get access token if not provided
    if not access_token:
        if not client_id or not client_secret:
            raise ValueError(
                "Either access_token or both client_id and client_secret must be provided"
            )
        access_token = get_access_token(client_id, client_secret)

    # Set up headers for API requests
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    # Search for albums from the specified year
    search_url = "https://api.spotify.com/v1/search"
    search_params = {
        "q": f"year:{year}",
        "type": "album",
        "limit": limit,
        "market": market,
    }

    search_response = requests.get(
        f"{search_url}?{urlencode(search_params)}", headers=headers
    )

    if search_response.status_code != 200:
        raise Exception(
            f"Search request failed with status code {search_response.status_code}: {search_response.text}"
        )

    search_data = search_response.json()
    albums = search_data.get("albums", {}).get("items", [])
    print(f"Found {len(albums)} albums in {year}.")

    # Fetch detailed information for each album to get popularity scores
    album_details = []
    for album in albums:
        album_id = album["id"]
        album_url = f"https://api.spotify.com/v1/albums/{album_id}"

        album_response = requests.get(album_url, headers=headers)

        if album_response.status_code == 200:
            album_data = album_response.json()
            album_details.append(album_data)
        else:
            print(
                f"Failed to get details for album {album['name']}: {album_response.status_code}"
            )

    # Sort albums by popularity (higher = more popular)
    sorted_albums = sorted(
        album_details, key=lambda x: x.get("popularity", 0), reverse=True
    )

    return sorted_albums


def display_top_albums(year, client_id, client_secret, limit=20):
    """
    Display the top albums for a specific year

    Args:
        year (int): The year to get top albums for
        client_id (str): Your Spotify API client ID
        client_secret (str): Your Spotify API client secret
        limit (int): Maximum number of albums to return
    """
    try:
        top_albums = get_top_albums_by_year(year, limit, client_id, client_secret)

        print(f"Top albums of {year}:")
        for index, album in enumerate(top_albums):
            artists = ", ".join([artist["name"] for artist in album["artists"]])
            print(
                f'{index + 1}. "{album["name"]}" by {artists} (Popularity: {album["popularity"]})'
            )

    except Exception as e:
        print(f"Error: {e}")


# Example usage
if __name__ == "__main__":
    # Replace with your Spotify API credentials
    CLIENT_ID = "YOUR_CLIENT_ID"
    CLIENT_SECRET = "YOUR_CLIENT_SECRET"
    YEAR = 2020  # Change to desired year

    display_top_albums(YEAR, CLIENT_ID, CLIENT_SECRET)

