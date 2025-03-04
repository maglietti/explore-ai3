/*******************************************************************************
   Chinook Database - Version 1.4.5
   Script: Chinook_MySql.sql
   Description: Creates and populates the Chinook database.
   DB Server: MySql
   Author: Luis Rocha
   License: https://github.com/lerocha/Chinook-database/blob/master/LICENSE.md
********************************************************************************/

/*******************************************************************************
   This SQL script is derived from the Chinook database distributed under the 
   license above. The script is adopted to Ignite SQL syntax (ANSI-99).
********************************************************************************/

/*******************************************************************************
   Drop Tables and Zones 
********************************************************************************/
DROP TABLE IF EXISTS Album;
DROP TABLE IF EXISTS Artist;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Employee;
DROP TABLE IF EXISTS Genre;
DROP TABLE IF EXISTS Invoice;
DROP TABLE IF EXISTS InvoiceLine;
DROP TABLE IF EXISTS MediaType;
DROP TABLE IF EXISTS Playlist;
DROP TABLE IF EXISTS PlaylistTrack;
DROP TABLE IF EXISTS Track;

DROP ZONE IF EXISTS Chinook;
DROP ZONE IF EXISTS ChinookReplicated;

/*******************************************************************************
   Create Zones
********************************************************************************/

CREATE ZONE IF NOT EXISTS Chinook WITH replicas=2, storage_profiles='default';
CREATE ZONE IF NOT EXISTS ChinookReplicated WITH replicas=3, partitions=25, storage_profiles='default';

/*******************************************************************************
   Create Tables
********************************************************************************/
CREATE TABLE Album
(
    AlbumId INT NOT NULL,
    Title VARCHAR(160) NOT NULL,
    ArtistId INT NOT NULL,
    ReleaseYear INT,
    PRIMARY KEY  (AlbumId, ArtistId)
) COLOCATE BY (ArtistId) ZONE Chinook;

CREATE TABLE Artist
(
    ArtistId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY  (ArtistId)
) ZONE Chinook;

CREATE TABLE Customer
(
    CustomerId INT NOT NULL,
    FirstName VARCHAR(40) NOT NULL,
    LastName VARCHAR(20) NOT NULL,
    Company VARCHAR(80),
    Address VARCHAR(70),
    City VARCHAR(40),
    State VARCHAR(40),
    Country VARCHAR(40),
    PostalCode VARCHAR(10),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    Email VARCHAR(60) NOT NULL,
    SupportRepId INT,
    PRIMARY KEY  (CustomerId)
) ZONE Chinook;

CREATE TABLE Employee
(
    EmployeeId INT NOT NULL,
    LastName VARCHAR(20) NOT NULL,
    FirstName VARCHAR(20) NOT NULL,
    Title VARCHAR(30),
    ReportsTo INT,
    BirthDate DATE,
    HireDate DATE,
    Address VARCHAR(70),
    City VARCHAR(40),
    State VARCHAR(40),
    Country VARCHAR(40),
    PostalCode VARCHAR(10),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    Email VARCHAR(60),
    PRIMARY KEY  (EmployeeId)
) ZONE Chinook;

CREATE TABLE Genre
(
    GenreId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY  (GenreId)
) ZONE ChinookReplicated;

CREATE TABLE Invoice
(
    InvoiceId INT NOT NULL,
    CustomerId INT NOT NULL,
    InvoiceDate DATE NOT NULL,
    BillingAddress VARCHAR(70),
    BillingCity VARCHAR(40),
    BillingState VARCHAR(40),
    BillingCountry VARCHAR(40),
    BillingPostalCode VARCHAR(10),
    Total NUMERIC(10,2) NOT NULL,
    PRIMARY KEY  (InvoiceId, CustomerId)
) COLOCATE BY (CustomerId) ZONE Chinook;

CREATE TABLE InvoiceLine
(
    InvoiceLineId INT NOT NULL,
    InvoiceId INT NOT NULL,
    TrackId INT NOT NULL,
    UnitPrice NUMERIC(10,2) NOT NULL,
    Quantity INT NOT NULL,
    PRIMARY KEY  (InvoiceLineId, InvoiceId)
) COLOCATE BY (InvoiceId) ZONE Chinook;

CREATE TABLE MediaType
(
    MediaTypeId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY  (MediaTypeId)
) ZONE ChinookReplicated;

CREATE TABLE Playlist
(
    PlaylistId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY  (PlaylistId)
) ZONE Chinook;

CREATE TABLE PlaylistTrack
(
    PlaylistId INT NOT NULL,
    TrackId INT NOT NULL,
    PRIMARY KEY  (PlaylistId, TrackId)
) ZONE Chinook;

CREATE TABLE Track
(
    TrackId INT NOT NULL,
    Name VARCHAR(200) NOT NULL,
    AlbumId INT,
    MediaTypeId INT NOT NULL,
    GenreId INT,
    Composer VARCHAR(220),
    Milliseconds INT NOT NULL,
    Bytes INT,
    UnitPrice NUMERIC(10,2) NOT NULL,
    PRIMARY KEY  (TrackId, AlbumId)
) COLOCATE BY (AlbumId) ZONE Chinook;
