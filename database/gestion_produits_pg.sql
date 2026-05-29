CREATE TABLE IF NOT EXISTS produits (
  pro_id          SERIAL PRIMARY KEY,
  pro_lib         VARCHAR(200) NOT NULL,
  pro_prix        DECIMAL(10,2) NOT NULL,
  pro_description TEXT
);

INSERT INTO produits (pro_id, pro_lib, pro_prix, pro_description) VALUES
(1,'Pédales Shimano XT M8040 M/L',74.99,'Les pédales plates SHIMANO XT PD-M8040 sont destinées à un usage All Mountain/Enduro.'),
(2,'Selle FIZIK ARIONE VERSUS Rails Kium',59.99,'Modèle confortable avant tout, la selle FIZIK Arione Versus possède un profil tout à fait plat et très long (300 mm).'),
(3,'Chaussures VTT MAVIC CROSSMAX SL PRO THERMO Noir',164.99,'Les chaussures Cross Max SL Pro Thermo créées par la marque MAVIC plairont aux riders voulant profiter de leur vélo en hiver.'),
(4,'Pack GPS GARMIN EDGE 1030 + Ceinture Cardio',519.99,'Le Pack GPS Edge 1030 plus la ceinture cardio de Garmin est fait pour les compétiteurs et les adeptes de performances.'),
(5,'Fourche DVO SAPPHIRE 29',549.99,'Dérivée de la Diamond, la fourche DVO Sapphire 29" marque l''entrée de la marque californienne dans le segment des fourches Trail.')
ON CONFLICT DO NOTHING;

SELECT setval('produits_pro_id_seq', (SELECT MAX(pro_id) FROM produits));

CREATE TABLE IF NOT EXISTS ressources (
  re_id   SERIAL PRIMARY KEY,
  re_type VARCHAR(100) NOT NULL,
  re_url  VARCHAR(1000) NOT NULL,
  re_nom  VARCHAR(100) DEFAULT NULL,
  pro_id  INTEGER NOT NULL,
  CONSTRAINT ressources_produits_fk FOREIGN KEY (pro_id) REFERENCES produits(pro_id)
);

INSERT INTO ressources (re_id, re_type, re_url, re_nom, pro_id) VALUES
(43,'img','uploads/5-b02cbdbc96d5c9a20526763576f56a11.jpg',NULL,5),
(44,'img','uploads/5-8e258524bf0f2aae28647a1aa8a77a8c.jpg',NULL,5),
(45,'img','uploads/4-438b7f4eec56d20aca694793882909ac.jpg',NULL,4),
(46,'img','uploads/1-707116622e5d4fe50dfc6391af4a5421.jpg',NULL,1)
ON CONFLICT DO NOTHING;

SELECT setval('ressources_re_id_seq', (SELECT MAX(re_id) FROM ressources));

CREATE TABLE IF NOT EXISTS utilisateurs (
  us_id       SERIAL PRIMARY KEY,
  us_login    VARCHAR(100) NOT NULL,
  us_password VARCHAR(100) NOT NULL,
  CONSTRAINT utilisateurs_login_unique UNIQUE (us_login)
);

INSERT INTO utilisateurs (us_login, us_password) VALUES
('admin','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8')
ON CONFLICT DO NOTHING;
