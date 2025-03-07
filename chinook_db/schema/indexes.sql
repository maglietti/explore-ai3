/*******************************************************************************
   Create Indexes for Foreign Key Relationships
********************************************************************************/
-- Album -> Artist relationship
CREATE INDEX IF NOT EXISTS IFK_AlbumArtistId ON Album (ArtistId);

-- Customer -> Employee relationship
CREATE INDEX IF NOT EXISTS IFK_CustomerSupportRepId ON Customer (SupportRepId);

-- Employee self-reference relationship
CREATE INDEX IF NOT EXISTS IFK_EmployeeReportsTo ON Employee (ReportsTo);

-- Invoice -> Customer relationship
CREATE INDEX IF NOT EXISTS IFK_InvoiceCustomerId ON Invoice (CustomerId);

-- InvoiceLine -> Invoice relationship
CREATE INDEX IF NOT EXISTS IFK_InvoiceLineInvoiceId ON InvoiceLine (InvoiceId);

-- InvoiceLine -> Track relationship
CREATE INDEX IF NOT EXISTS IFK_InvoiceLineTrackId ON InvoiceLine (TrackId);

-- PlaylistTrack -> Playlist relationship
CREATE INDEX IF NOT EXISTS IFK_PlaylistTrackPlaylistId ON PlaylistTrack (PlaylistId);

-- PlaylistTrack -> Track relationship
CREATE INDEX IF NOT EXISTS IFK_PlaylistTrackTrackId ON PlaylistTrack (TrackId);

-- Track -> Album relationship
CREATE INDEX IF NOT EXISTS IFK_TrackAlbumId ON Track (AlbumId);

-- Track -> Genre relationship
CREATE INDEX IF NOT EXISTS IFK_TrackGenreId ON Track (GenreId);

-- Track -> MediaType relationship
CREATE INDEX IF NOT EXISTS IFK_TrackMediaTypeId ON Track (MediaTypeId);