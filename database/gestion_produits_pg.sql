-- Schéma PostgreSQL de l'application gestion-produits
-- Adapté depuis le dump MySQL original
-- Note: la base est créée automatiquement via POSTGRES_DB dans docker-compose

-- Table produits
CREATE TABLE produits (
  "PRO_id"          SERIAL PRIMARY KEY,
  "PRO_lib"         VARCHAR(200) NOT NULL,
  "PRO_prix"        DECIMAL(10,2) NOT NULL,
  "PRO_description" TEXT
);

INSERT INTO produits ("PRO_id","PRO_lib","PRO_prix","PRO_description") VALUES
(1,'Pédales Shimano XT M8040 M/L',74.99,'Les pédales plates SHIMANO XT PD-M8040 sont destinées à un usage All Mountain/Enduro.'),
(2,'Selle FIZIK ARIONE VERSUS Rails Kium',59.99,'Modèle confortable avant tout, la selle FIZIK Arione Versus possède un profil tout à fait plat et très long (300 mm).'),
(3,'Chaussures VTT MAVIC CROSSMAX SL PRO THERMO Noir',164.99,'Les chaussures Cross Max SL Pro Thermo créées par la marque MAVIC plairont aux riders voulant profiter de leur vélo en hiver.'),
(4,'Pack GPS GARMIN EDGE 1030 + Ceinture Cardio',519.99,'Le Pack GPS Edge 1030 plus la ceinture cardio de Garmin est fait pour les compétiteurs et les adeptes de performances.'),
(5,'Fourche DVO SAPPHIRE 29',549.99,'Dérivée de la Diamond, la fourche DVO Sapphire 29" marque l''entrée de la marque californienne dans le segment des fourches Trail.');

-- Réinitialiser la séquence après insertion manuelle des IDs
SELECT setval('"produits_PRO_id_seq"', (SELECT MAX("PRO_id") FROM produits));

-- Table ressources
CREATE TABLE ressources (
  "RE_id"   SERIAL PRIMARY KEY,
  "RE_type" VARCHAR(100) NOT NULL,
  "RE_url"  VARCHAR(1000) NOT NULL,
  "RE_nom"  VARCHAR(100) DEFAULT NULL,
  "PRO_id"  INTEGER NOT NULL,
  CONSTRAINT ressources_produits_fk FOREIGN KEY ("PRO_id") REFERENCES produits("PRO_id")
);

INSERT INTO ressources ("RE_id","RE_type","RE_url","RE_nom","PRO_id") VALUES
(43,'img','uploads/5-b02cbdbc96d5c9a20526763576f56a11.jpg',NULL,5),
(44,'img','uploads/5-8e258524bf0f2aae28647a1aa8a77a8c.jpg',NULL,5),
(45,'img','uploads/4-438b7f4eec56d20aca694793882909ac.jpg',NULL,4),
(46,'img','uploads/1-707116622e5d4fe50dfc6391af4a5421.jpg',NULL,1);

SELECT setval('"ressources_RE_id_seq"', (SELECT MAX("RE_id") FROM ressources));

-- Table utilisateurs (mot de passe : "password" hashé en SHA256)
CREATE TABLE utilisateurs (
  "US_id"       SERIAL PRIMARY KEY,
  "US_login"    VARCHAR(100) NOT NULL,
  "US_password" VARCHAR(100) NOT NULL,
  CONSTRAINT utilisateurs_login_unique UNIQUE ("US_login")
);

INSERT INTO utilisateurs ("US_login","US_password") VALUES
('admin','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');
