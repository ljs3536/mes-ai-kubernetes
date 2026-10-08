-- MES Core MariaDB 스키마.
-- 실행 중인 factory-mes DB의 SHOW CREATE TABLE과 같게 맞춘다.
-- 상태값은 애플리케이션 enum이며 DB CHECK로 고정하지 않는다.
--   lots.status: RAW, WIP, PROCESSED, HOLD, IN_STOCK, SHIPPED
--   work_orders.status: PLANNED, IN_PROGRESS, COMPLETED, HOLD, CANCELLED
--   machines.status: IDLE, RUN, STOP, WARNING
--   inspections.result: PASS, FAIL, PENDING
-- 컨테이너 최초 기동 시 docker-entrypoint-initdb.d에서 mes DB에 실행된다.
-- InfluxDB(센서 파형)와 MLflow(모델)는 이 스키마에 포함하지 않는다.

CREATE TABLE IF NOT EXISTS operators (
  id int(11) NOT NULL AUTO_INCREMENT,
  employee_no varchar(32) NOT NULL,
  name varchar(64) NOT NULL,
  role varchar(16) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY employee_no (employee_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS machines (
  id int(11) NOT NULL AUTO_INCREMENT,
  code varchar(32) NOT NULL,
  name varchar(64) NOT NULL,
  type varchar(32) NOT NULL,
  status varchar(16) NOT NULL,
  last_seen_at datetime DEFAULT NULL,
  last_telemetry longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(last_telemetry)),
  PRIMARY KEY (id),
  UNIQUE KEY code (code),
  KEY ix_machines_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lots (
  id int(11) NOT NULL AUTO_INCREMENT,
  lot_no varchar(32) NOT NULL,
  material_name varchar(128) NOT NULL,
  quantity int(11) NOT NULL,
  status varchar(16) NOT NULL,
  location varchar(64) NOT NULL,
  updated_at datetime NOT NULL DEFAULT current_timestamp(),
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  UNIQUE KEY lot_no (lot_no),
  KEY ix_lots_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS work_orders (
  id int(11) NOT NULL AUTO_INCREMENT,
  wo_no varchar(32) NOT NULL,
  product_name varchar(128) NOT NULL,
  quantity int(11) NOT NULL,
  status varchar(16) NOT NULL,
  machine_id int(11) NOT NULL,
  lot_id int(11) NOT NULL,
  operator_id int(11) DEFAULT NULL,
  started_at datetime DEFAULT NULL,
  produced_qty int(11) NOT NULL,
  completed_at datetime DEFAULT NULL,
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  UNIQUE KEY wo_no (wo_no),
  KEY machine_id (machine_id),
  KEY lot_id (lot_id),
  KEY operator_id (operator_id),
  KEY ix_work_orders_status (status),
  CONSTRAINT work_orders_ibfk_1 FOREIGN KEY (machine_id) REFERENCES machines (id),
  CONSTRAINT work_orders_ibfk_2 FOREIGN KEY (lot_id) REFERENCES lots (id),
  CONSTRAINT work_orders_ibfk_3 FOREIGN KEY (operator_id) REFERENCES operators (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS inspections (
  id int(11) NOT NULL AUTO_INCREMENT,
  lot_id int(11) NOT NULL,
  result varchar(16) NOT NULL,
  note varchar(255) DEFAULT NULL,
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  KEY lot_id (lot_id),
  CONSTRAINT inspections_ibfk_1 FOREIGN KEY (lot_id) REFERENCES lots (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS shipments (
  id int(11) NOT NULL AUTO_INCREMENT,
  ship_no varchar(32) NOT NULL,
  lot_id int(11) NOT NULL,
  quantity int(11) NOT NULL,
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  UNIQUE KEY ship_no (ship_no),
  KEY lot_id (lot_id),
  CONSTRAINT shipments_ibfk_1 FOREIGN KEY (lot_id) REFERENCES lots (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS trace_events (
  id int(11) NOT NULL AUTO_INCREMENT,
  lot_id int(11) NOT NULL,
  type varchar(32) NOT NULL,
  message text NOT NULL,
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  KEY ix_trace_events_lot_id (lot_id),
  CONSTRAINT trace_events_ibfk_1 FOREIGN KEY (lot_id) REFERENCES lots (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS alerts (
  id int(11) NOT NULL AUTO_INCREMENT,
  machine_id int(11) DEFAULT NULL,
  severity varchar(16) NOT NULL,
  title varchar(255) NOT NULL,
  message text NOT NULL,
  acknowledged tinyint(1) NOT NULL,
  created_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id),
  KEY machine_id (machine_id),
  CONSTRAINT alerts_ibfk_1 FOREIGN KEY (machine_id) REFERENCES machines (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sensor_readings (
  id bigint(20) NOT NULL AUTO_INCREMENT,
  machine_id int(11) NOT NULL,
  work_order_id int(11) DEFAULT NULL,
  sensor_code varchar(32) NOT NULL,
  value float NOT NULL,
  unit varchar(16) NOT NULL,
  recorded_at datetime NOT NULL,
  PRIMARY KEY (id),
  KEY work_order_id (work_order_id),
  KEY ix_sensor_readings_machine_time (machine_id, recorded_at),
  CONSTRAINT sensor_readings_ibfk_1 FOREIGN KEY (machine_id) REFERENCES machines (id),
  CONSTRAINT sensor_readings_ibfk_2 FOREIGN KEY (work_order_id) REFERENCES work_orders (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS machine_sensors (
  id int(11) NOT NULL AUTO_INCREMENT,
  machine_id int(11) NOT NULL,
  code varchar(32) NOT NULL,
  name varchar(64) NOT NULL,
  sensor_type varchar(16) NOT NULL,
  mount varchar(64) NOT NULL,
  unit varchar(16) NOT NULL,
  sample_rate int(11) NOT NULL,
  n_samples int(11) NOT NULL,
  interval_s int(11) NOT NULL,
  preset varchar(32) NOT NULL,
  severity float NOT NULL,
  enabled tinyint(1) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_machine_sensor_code (machine_id, code),
  KEY machine_id (machine_id),
  CONSTRAINT machine_sensors_ibfk_1 FOREIGN KEY (machine_id) REFERENCES machines (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
