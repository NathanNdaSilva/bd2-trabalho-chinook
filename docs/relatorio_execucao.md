# 📄 Relatório de Implementação e Evidências de Execução

Este documento reúne as explicações das estratégias adotadas e os resultados obtidos na execução das questões do trabalho de Banco de Dados II sobre o esquema **Chinook**.

---

## Parte 1

### Questão 1 – Consulta ao Catálogo de Índices

Para resolver a questão, foi utilizada uma consulta SQL à tabela de catálogo `information_schema.statistics`, que contém as informações dos índices existentes no esquema `chinook`[cite: 9].

Foram selecionados os nomes dos índices, suas respectivas tabelas e colunas indexadas[cite: 9]. Também foi utilizada a função `GROUP_CONCAT` para reunir, em uma única linha, as colunas pertencentes ao mesmo índice, respeitando sua ordem[cite: 9].

#### Saída Obtida:

| # | Tabela | Índice | Coluna(s) | Tipo |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `album` | `IFK_AlbumArtistId` | `ArtistId` | Secundário Não-Único[cite: 9] |
| 2 | `album` | `PRIMARY` | `AlbumId` | Primário (PK / Único)[cite: 9] |
| 3 | `artist` | `PRIMARY` | `ArtistId` | Primário (PK / Único)[cite: 9] |
| 4 | `customer` | `IFK_CustomerSupportRepId` | `SupportRepId` | Secundário Não-Único[cite: 9] |
| 5 | `customer` | `PRIMARY` | `CustomerId` | Primário (PK / Único)[cite: 9] |
| 6 | `employee` | `IFK_EmployeeReportsTo` | `ReportsTo` | Secundário Não-Único[cite: 9] |
| 7 | `employee` | `PRIMARY` | `EmployeeId` | Primário (PK / Único)[cite: 9] |
| 8 | `genre` | `PRIMARY` | `GenreId` | Primário (PK / Único)[cite: 9] |
| 9 | `invoice` | `IFK_InvoiceCustomerId` | `CustomerId` | Secundário Não-Único[cite: 9] |
| 10 | `invoice` | `PRIMARY` | `InvoiceId` | Primário (PK / Único)[cite: 9] |
| 11 | `invoiceline` | `IFK_InvoiceLineInvoiceId` | `InvoiceId` | Secundário Não-Único[cite: 9] |
| 12 | `invoiceline` | `IFK_InvoiceLineTrackId` | `TrackId` | Secundário Não-Único[cite: 9] |
| 13 | `invoiceline` | `PRIMARY` | `InvoiceLineId` | Primário (PK / Único)[cite: 9] |
| 14 | `mediatype` | `PRIMARY` | `MediaTypeId` | Primário (PK / Único)[cite: 9] |
| 15 | `playlist` | `PRIMARY` | `PlaylistId` | Primário (PK / Único)[cite: 9] |
| 16 | `playlisttrack` | `IFK_PlaylistTrackPlaylistId` | `PlaylistId` | Secundário Não-Único[cite: 9] |
| 17 | `playlisttrack` | `IFK_PlaylistTrackTrackId` | `TrackId` | Secundário Não-Único[cite: 9] |
| 18 | `playlisttrack` | `PRIMARY` | `PlaylistId, TrackId` | Primário (PK / Único)[cite: 9] |
| 19 | `track` | `IFK_TrackAlbumId` | `AlbumId` | Secundário Não-Único[cite: 9] |
| 20 | `track` | `IFK_TrackGenreId` | `GenreId` | Secundário Não-Único[cite: 9] |
| 21 | `track` | `IFK_TrackMediaTypeId` | `MediaTypeId` | Secundário Não-Único[cite: 9] |
| 22 | `track` | `PRIMARY` | `TrackId` | Primário (PK / Único)[cite: 9] |

---

### Questão 4 – Gerador Dinâmico de DDL (`CREATE TABLE`)

A solução foi dividida em três procedimentos, cada um responsável por uma parte da geração dos comandos de `CREATE TABLE`[cite: 9]:

* **`ObterTipagemColunasTabela`**: Busca as informações das colunas na tabela `information_schema.columns`, como nome, tipo de dado, presença de auto incremento, aceitação de valores nulos e valor padrão[cite: 9]. Essas informações são armazenadas em uma tabela temporária[cite: 9].
* **`ObterRestricoesTabela`**: Busca as restrições de cada tabela, como `Primary Key`, `Foreign Key`, `Unique` e `Check`, utilizando as tabelas `information_schema.table_constraints`, `key_column_usage` e `check_constraints`[cite: 9]. Também foi utilizada a função `GROUP_CONCAT` para reunir as colunas de chaves primárias compostas[cite: 9].
* **`GerarCreateTablesSchema`**: Organiza o processo[cite: 9]. Ele percorre as tabelas do esquema em ordem alfabética, chama os dois procedimentos auxiliares e utiliza as informações obtidas para montar os comandos, utilizando uma estratégia de criação em duas etapas[cite: 9]:
  1. Gera os comandos `CREATE TABLE` com as colunas e restrições, exceto as chaves estrangeiras[cite: 9].
  2. Depois que todas as tabelas são criadas, são gerados comandos `ALTER TABLE` para adicionar as chaves estrangeiras de cada tabela, garantindo que os relacionamentos sejam adicionados somente depois que todas as tabelas já existem[cite: 9].

#### Saída Obtida:

```sql
CREATE TABLE `album` (
    `AlbumId` int NOT NULL,
    `Title` varchar(160) NOT NULL,
    `ArtistId` int NOT NULL,
    PRIMARY KEY (`AlbumId`)
);

CREATE TABLE `artist` (
    `ArtistId` int NOT NULL,
    `Name` varchar(120) NULL,
    PRIMARY KEY (`ArtistId`)
);

CREATE TABLE `customer` (
    `CustomerId` int NOT NULL,
    `FirstName` varchar(40) NOT NULL,
    `LastName` varchar(20) NOT NULL,
    `Company` varchar(80) NULL,
    `Address` varchar(70) NULL,
    `City` varchar(40) NULL,
    `State` varchar(40) NULL,
    `Country` varchar(40) NULL,
    `PostalCode` varchar(10) NULL,
    `Phone` varchar(24) NULL,
    `Fax` varchar(24) NULL,
    `Email` varchar(60) NOT NULL,
    `SupportRepId` int NULL,
    PRIMARY KEY (`CustomerId`)
);

CREATE TABLE `employee` (
    `EmployeeId` int NOT NULL,
    `LastName` varchar(20) NOT NULL,
    `FirstName` varchar(20) NOT NULL,
    `Title` varchar(30) NULL,
    `ReportsTo` int NULL,
    `BirthDate` datetime NULL,
    `HireDate` datetime NULL,
    `Address` varchar(70) NULL,
    `City` varchar(40) NULL,
    `State` varchar(40) NULL,
    `Country` varchar(40) NULL,
    `PostalCode` varchar(10) NULL,
    `Phone` varchar(24) NULL,
    `Fax` varchar(24) NULL,
    `Email` varchar(60) NULL,
    PRIMARY KEY (`EmployeeId`)
);

CREATE TABLE `genre` (
    `GenreId` int NOT NULL,
    `Name` varchar(120) NULL,
    PRIMARY KEY (`GenreId`)
);

CREATE TABLE `invoice` (
    `InvoiceId` int NOT NULL,
    `CustomerId` int NOT NULL,
    `InvoiceDate` datetime NOT NULL,
    `BillingAddress` varchar(70) NULL,
    `BillingCity` varchar(40) NULL,
    `BillingState` varchar(40) NULL,
    `BillingCountry` varchar(40) NULL,
    `BillingPostalCode` varchar(10) NULL,
    `Total` decimal(10,2) NOT NULL,
    PRIMARY KEY (`InvoiceId`)
);

CREATE TABLE `invoiceline` (
    `InvoiceLineId` int NOT NULL,
    `InvoiceId` int NOT NULL,
    `TrackId` int NOT NULL,
    `UnitPrice` decimal(10,2) NOT NULL,
    `Quantity` int NOT NULL,
    PRIMARY KEY (`InvoiceLineId`)
);

CREATE TABLE `mediatype` (
    `MediaTypeId` int NOT NULL,
    `Name` varchar(120) NULL,
    PRIMARY KEY (`MediaTypeId`)
);

CREATE TABLE `playlist` (
    `PlaylistId` int NOT NULL,
    `Name` varchar(120) NULL,
    PRIMARY KEY (`PlaylistId`)
);

CREATE TABLE `playlisttrack` (
    `PlaylistId` int NOT NULL,
    `TrackId` int NOT NULL,
    PRIMARY KEY (`PlaylistId`, `TrackId`)
);

CREATE TABLE `track` (
    `TrackId` int NOT NULL,
    `Name` varchar(200) NOT NULL,
    `AlbumId` int NULL,
    `MediaTypeId` int NOT NULL,
    `GenreId` int NULL,
    `Composer` varchar(220) NULL,
    `Milliseconds` int NOT NULL,
    `Bytes` int NULL,
    `UnitPrice` decimal(10,2) NOT NULL,
    PRIMARY KEY (`TrackId`)
);

-- RESTRIÇÕES DE CHAVE ESTRANGEIRA (ALTER TABLE)
ALTER TABLE `album` ADD CONSTRAINT `FK_AlbumArtistId` FOREIGN KEY (`ArtistId`) REFERENCES `artist` (`ArtistId`);
ALTER TABLE `customer` ADD CONSTRAINT `FK_CustomerSupportRepId` FOREIGN KEY (`SupportRepId`) REFERENCES `employee` (`EmployeeId`);
ALTER TABLE `employee` ADD CONSTRAINT `FK_EmployeeReportsTo` FOREIGN KEY (`ReportsTo`) REFERENCES `employee` (`EmployeeId`);
ALTER TABLE `invoice` ADD CONSTRAINT `FK_InvoiceCustomerId` FOREIGN KEY (`CustomerId`) REFERENCES `customer` (`CustomerId`);
ALTER TABLE `invoiceline` ADD CONSTRAINT `FK_InvoiceLineInvoiceId` FOREIGN KEY (`InvoiceId`) REFERENCES `invoice` (`InvoiceId`);
ALTER TABLE `invoiceline` ADD CONSTRAINT `FK_InvoiceLineTrackId` FOREIGN KEY (`TrackId`) REFERENCES `track` (`TrackId`);
ALTER TABLE `playlisttrack` ADD CONSTRAINT `FK_PlaylistTrackPlaylistId` FOREIGN KEY (`PlaylistId`) REFERENCES `playlist` (`PlaylistId`);
ALTER TABLE `playlisttrack` ADD CONSTRAINT `FK_PlaylistTrackTrackId` FOREIGN KEY (`TrackId`) REFERENCES `track` (`TrackId`);
ALTER TABLE `track` ADD CONSTRAINT `FK_TrackAlbumId` FOREIGN KEY (`AlbumId`) REFERENCES `album` (`AlbumId`);
ALTER TABLE `track` ADD CONSTRAINT `FK_TrackGenreId` FOREIGN KEY (`GenreId`) REFERENCES `genre` (`GenreId`);
ALTER TABLE `track` ADD CONSTRAINT `FK_TrackMediaTypeId` FOREIGN KEY (`MediaTypeId`) REFERENCES `mediatype` (`MediaTypeId`);
