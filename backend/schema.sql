CREATE TABLE IF NOT EXISTS alerts (
    id VARCHAR(36) PRIMARY KEY,
    type VARCHAR(20) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    user_id VARCHAR(50),
    upvotes INT DEFAULT 0,
    downvotes INT DEFAULT 0
);

CREATE INDEX idx_location ON alerts (latitude, longitude);
CREATE INDEX idx_timestamp ON alerts (timestamp);

CREATE TABLE IF NOT EXISTS user_positions (
    user_id VARCHAR(50) PRIMARY KEY,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_last_seen ON user_positions (last_seen);
