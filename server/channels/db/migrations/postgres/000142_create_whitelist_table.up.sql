CREATE TABLE IF NOT EXISTS whitelist (
    userid varchar(26) NOT NULL,
    ip varchar(39) NOT NULL,
    PRIMARY KEY (userid, ip)
);

CREATE INDEX IF NOT EXISTS idx_whitelist_user_id ON whitelist (userid); 