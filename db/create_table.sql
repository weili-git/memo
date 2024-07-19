CREATE TABLE words (
    id INT AUTO_INCREMENT PRIMARY KEY,
    word VARCHAR(255) UNIQUE NOT NULL,
    meaning TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_reviewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    review_count INT DEFAULT 0,
    deleted BOOLEAN DEFAULT FALSE
);
