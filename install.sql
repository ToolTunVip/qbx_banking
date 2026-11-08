-- Resource tự tạo bảng/cột khi khởi động. File này chỉ để chạy tay nếu cần.

CREATE TABLE IF NOT EXISTS `qbx_banking_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `receiver_identifier` varchar(64) NOT NULL,
  `receiver_name` varchar(255) NOT NULL DEFAULT '',
  `sender_identifier` varchar(64) NOT NULL,
  `sender_name` varchar(255) NOT NULL DEFAULT '',
  `date` timestamp NOT NULL DEFAULT current_timestamp(),
  `value` bigint(20) NOT NULL,
  `type` varchar(32) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `receiver_identifier` (`receiver_identifier`),
  KEY `sender_identifier` (`sender_identifier`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- MariaDB:
ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `pincode` varchar(4) DEFAULT NULL;
