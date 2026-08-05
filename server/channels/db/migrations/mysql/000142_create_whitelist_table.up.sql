CREATE TABLE IF NOT EXISTS Whitelist (
    UserId varchar(26) NOT NULL,
    IP varchar(39) NOT NULL,
    PRIMARY KEY (UserId, IP),
    KEY idx_whitelist_user_id (UserId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; 