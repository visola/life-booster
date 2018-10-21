CREATE TABLE project (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  NAME VARCHAR(255) NOT NULL,
  user_id BINARY(16) NOT NULL REFERENCES user(id),
  created BIGINT
);