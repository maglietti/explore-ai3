
/*******************************************************************************
   Chinook Database - Version 1.4.5
   Script: chinook_ignite3.sql
   Description: Creates and populates the Chinook database.
   DB Server: Ignite 3
   Author: Luis Rocha
   License: https://github.com/lerocha/Chinook-database/blob/master/LICENSE.md
********************************************************************************/

/*******************************************************************************
   This SQL script is derived from the Chinook database distributed under the 
   license above. The script is adopted to Ignite SQL syntax (ANSI-99).
********************************************************************************/

/*******************************************************************************
   Populate Tables
********************************************************************************/

INSERT INTO Genre (GenreId, Name) VALUES
    (1, 'Rock'),
    (2, 'Jazz'),
    (3, 'Metal'),
    (4, 'Alternative & Punk'),
    (5, 'Rock And Roll');

INSERT INTO MediaType (MediaTypeId, Name) VALUES
    (1, 'MPEG audio file'),
    (2, 'Protected AAC audio file'),
    (3, 'Protected MPEG-4 video file'),
    (4, 'Purchased AAC audio file'),
    (5, 'AAC audio file');

INSERT INTO Artist (ArtistId, Name) VALUES
    (1, 'AC/DC'),
    (2, 'Accept'),
    (3, 'Aerosmith'),
    (4, 'Alanis Morissette'),
    (5, 'Alice In Chains');

INSERT INTO Album (AlbumId, Title, ArtistId) VALUES
    (1, 'For Those About To Rock We Salute You', 1),
    (2, 'Balls to the Wall', 2),
    (3, 'Restless and Wild', 2),
    (4, 'Let There Be Rock', 1),
    (5, 'Big Ones', 3);

INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
    (1, 'For Those About To Rock (We Salute You)', 1, 1, 1, 'Angus Young, Malcolm Young, Brian Johnson', 343719, 11170334, 0.99),
    (2, 'Balls to the Wall', 2, 2, 1, 'U. Dirkschneider, W. Hoffmann, H. Frank, P. Baltes, S. Kaufmann, G. Hoffmann', 342562, 5510424, 0.99),
    (3, 'Fast As a Shark', 3, 2, 1, 'F. Baltes, S. Kaufman, U. Dirkscneider & W. Hoffman', 230619, 3990994, 0.99),
    (4, 'Restless and Wild', 3, 2, 1, 'F. Baltes, R.A. Smith-Diesel, S. Kaufman, U. Dirkscneider & W. Hoffman', 252051, 4331779, 0.99),
    (5, 'Princess of the Dawn', 3, 2, 1, 'Deaffy & R.A. Smith-Diesel', 375418, 6290521, 0.99);

INSERT INTO Employee (EmployeeId, LastName, FirstName, Title, ReportsTo, BirthDate, HireDate, Address, City, State, Country, PostalCode, Phone, Fax, Email) VALUES
    (1, 'Adams', 'Andrew', 'General Manager', NULL, date '1962-02-018', date '2002-08-014', '11120 Jasper Ave NW', 'Edmonton', 'AB', 'Canada', 'T5K 2N1', '+1 (780) 428-9482', '+1 (780) 428-3457', 'andrew@chinookcorp.com'),
    (2, 'Edwards', 'Nancy', 'Sales Manager', 1, date '1958-012-08', date '2002-05-01', '825 8 Ave SW', 'Calgary', 'AB', 'Canada', 'T2P 2T3', '+1 (403) 262-3443', '+1 (403) 262-3322', 'nancy@chinookcorp.com'),
    (3, 'Peacock', 'Jane', 'Sales Support Agent', 2, date '1973-08-029', date '2002-04-01', '1111 6 Ave SW', 'Calgary', 'AB', 'Canada', 'T2P 5M5', '+1 (403) 262-3443', '+1 (403) 262-6712', 'jane@chinookcorp.com'),
    (4, 'Park', 'Margaret', 'Sales Support Agent', 2, date '1947-09-019', date '2003-05-03', '683 10 Street SW', 'Calgary', 'AB', 'Canada', 'T2P 5G3', '+1 (403) 263-4423', '+1 (403) 263-4289', 'margaret@chinookcorp.com'),
    (5, 'Johnson', 'Steve', 'Sales Support Agent', 2, date '1965-03-03', date '2003-010-017', '7727B 41 Ave', 'Calgary', 'AB', 'Canada', 'T3B 1Y7', '1 (780) 836-9987', '1 (780) 836-9543', 'steve@chinookcorp.com');

INSERT INTO Customer (CustomerId, FirstName, LastName, Company, Address, City, State, Country, PostalCode, Phone, Fax, Email, SupportRepId) VALUES
    (1, 'Luís', 'Gonçalves', 'Embraer - Empresa Brasileira de Aeronáutica S.A.', 'Av. Brigadeiro Faria Lima, 2170', 'São José dos Campos', 'SP', 'Brazil', '12227-000', '+55 (12) 3923-5555', '+55 (12) 3923-5566', 'luisg@embraer.com.br', 3),
    (2, 'Leonie', 'Köhler', NULL, 'Theodor-Heuss-Straße 34', 'Stuttgart', NULL, 'Germany', '70174', '+49 0711 2842222', NULL, 'leonekohler@surfeu.de', 5),
    (3, 'François', 'Tremblay', NULL, '1498 rue Bélanger', 'Montréal', 'QC', 'Canada', 'H2G 1A7', '+1 (514) 721-4711', NULL, 'ftremblay@gmail.com', 3),
    (4, 'Bjørn', 'Hansen', NULL, 'Ullevålsveien 14', 'Oslo', NULL, 'Norway', '0171', '+47 22 44 22 22', NULL, 'bjorn.hansen@yahoo.no', 4),
    (5, 'František', 'Wichterlová', 'JetBrains s.r.o.', 'Klanova 9/506', 'Prague', NULL, 'Czech Republic', '14700', '+420 2 4172 5555', '+420 2 4172 5555', 'frantisekw@jetbrains.com', 4);

INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, BillingAddress, BillingCity, BillingState, BillingCountry, BillingPostalCode, Total) VALUES
    (1, 2, date '2021-01-01', 'Theodor-Heuss-Straße 34', 'Stuttgart', NULL, 'Germany', '70174', 1.98),
    (2, 4, date '2021-01-02', 'Ullevålsveien 14', 'Oslo', NULL, 'Norway', '0171', 3.96),
    (3, 8, date '2021-01-03', 'Grétrystraat 63', 'Brussels', NULL, 'Belgium', '1000', 5.94),
    (4, 14, date '2021-01-06', '8210 111 ST NW', 'Edmonton', 'AB', 'Canada', 'T6G 2C7', 8.91),
    (5, 23, date '2021-01-011', '69 Salem Street', 'Boston', 'MA', 'USA', '2113', 13.86);

INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity) VALUES
    (1, 1, 2, 0.99, 1),
    (2, 1, 4, 0.99, 1),
    (3, 2, 6, 0.99, 1),
    (4, 2, 8, 0.99, 1),
    (5, 2, 10, 0.99, 1);

INSERT INTO Playlist (PlaylistId, Name) VALUES
    (1, 'Music'),
    (2, 'Movies'),
    (3, 'TV Shows'),
    (4, 'Audiobooks'),
    (5, '90’s Music');

INSERT INTO PlaylistTrack (PlaylistId, TrackId) VALUES
    (1, 3402),
    (1, 3389),
    (1, 3390),
    (1, 3391),
    (1, 3392);

