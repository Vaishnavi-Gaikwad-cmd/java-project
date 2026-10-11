-- MediCare HMS schema (PostgreSQL). Run after: CREATE DATABASE hospital_db;
DROP TABLE IF EXISTS payments, bill_items, bills, admissions, beds, wards, prescription_items,
    prescriptions, medicines, medical_records, appointments, doctors, departments, patients, users CASCADE;

CREATE TABLE users (
    user_id        SERIAL PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    full_name      VARCHAR(100) NOT NULL,
    role           VARCHAR(20)  NOT NULL CHECK (role IN ('ADMIN','DOCTOR','RECEPTIONIST','ACCOUNTANT')),
    status         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE departments (
    department_id  SERIAL PRIMARY KEY,
    name           VARCHAR(80) NOT NULL UNIQUE
);

CREATE SEQUENCE patient_id_seq START 10001;
CREATE TABLE patients (
    patient_id               INT PRIMARY KEY DEFAULT nextval('patient_id_seq'),
    first_name               VARCHAR(50) NOT NULL,
    last_name                VARCHAR(50) NOT NULL,
    date_of_birth            DATE NOT NULL CHECK (date_of_birth <= CURRENT_DATE),
    gender                   VARCHAR(10) NOT NULL CHECK (gender IN ('MALE','FEMALE','OTHER')),
    blood_group              VARCHAR(5) CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    phone                    VARCHAR(15) NOT NULL,
    email                    VARCHAR(100),
    address                  TEXT,
    emergency_contact_name   VARCHAR(100),
    emergency_contact_phone  VARCHAR(15),
    insurance_provider       VARCHAR(100),
    insurance_number         VARCHAR(50),
    allergies                TEXT,
    existing_conditions      TEXT,
    registration_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    status                   VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    UNIQUE (first_name, last_name, date_of_birth, phone)
);
ALTER SEQUENCE patient_id_seq OWNED BY patients.patient_id;

CREATE TABLE doctors (
    doctor_id         SERIAL PRIMARY KEY,
    user_id           INT UNIQUE REFERENCES users(user_id) ON DELETE SET NULL,
    full_name         VARCHAR(100) NOT NULL,
    gender            VARCHAR(10) NOT NULL CHECK (gender IN ('MALE','FEMALE','OTHER')),
    date_of_birth     DATE,
    specialization    VARCHAR(80) NOT NULL,
    department_id     INT NOT NULL REFERENCES departments(department_id),
    qualification     VARCHAR(100),
    experience_years  INT NOT NULL DEFAULT 0 CHECK (experience_years >= 0),
    phone             VARCHAR(15) NOT NULL,
    email             VARCHAR(100) NOT NULL UNIQUE,
    consultation_fee  NUMERIC(10,2) NOT NULL CHECK (consultation_fee >= 0),
    joining_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    status            VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE'))
);

CREATE TABLE appointments (
    appointment_id    SERIAL PRIMARY KEY,
    patient_id        INT NOT NULL REFERENCES patients(patient_id),
    doctor_id         INT NOT NULL REFERENCES doctors(doctor_id),
    appointment_date  DATE NOT NULL,
    appointment_time  TIME NOT NULL,
    appointment_type  VARCHAR(30) NOT NULL DEFAULT 'CONSULTATION',
    reason            TEXT,
    status            VARCHAR(15) NOT NULL DEFAULT 'SCHEDULED'
                      CHECK (status IN ('SCHEDULED','CONFIRMED','COMPLETED','CANCELLED','NO_SHOW')),
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Database-level double-booking guard (cancelled / no-show slots can be reused)
CREATE UNIQUE INDEX uq_doctor_slot ON appointments (doctor_id, appointment_date, appointment_time)
    WHERE status NOT IN ('CANCELLED','NO_SHOW');

CREATE TABLE medical_records (
    record_id        SERIAL PRIMARY KEY,
    patient_id       INT NOT NULL REFERENCES patients(patient_id),
    doctor_id        INT NOT NULL REFERENCES doctors(doctor_id),
    visit_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    chief_complaint  TEXT,
    symptoms         TEXT,
    diagnosis        TEXT NOT NULL,
    blood_pressure   VARCHAR(10),
    heart_rate       INT CHECK (heart_rate IS NULL OR heart_rate > 0),
    temperature      NUMERIC(4,1),
    weight_kg        NUMERIC(5,1) CHECK (weight_kg IS NULL OR weight_kg > 0),
    height_cm        NUMERIC(5,1) CHECK (height_cm IS NULL OR height_cm > 0),
    notes            TEXT,
    follow_up_date   DATE
);

CREATE TABLE prescriptions (
    prescription_id  SERIAL PRIMARY KEY,
    patient_id       INT NOT NULL REFERENCES patients(patient_id),
    doctor_id        INT NOT NULL REFERENCES doctors(doctor_id),
    record_id        INT REFERENCES medical_records(record_id),
    prescription_date DATE NOT NULL DEFAULT CURRENT_DATE,
    diagnosis        TEXT,
    notes            TEXT
);

CREATE TABLE medicines (
    medicine_id      SERIAL PRIMARY KEY,
    name             VARCHAR(100) NOT NULL,
    category         VARCHAR(50),
    manufacturer     VARCHAR(100),
    batch_number     VARCHAR(50) NOT NULL,
    quantity         INT NOT NULL CHECK (quantity >= 0),
    min_stock_level  INT NOT NULL DEFAULT 20 CHECK (min_stock_level >= 0),
    unit_price       NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    expiry_date      DATE NOT NULL,
    supplier         VARCHAR(100),
    UNIQUE (name, batch_number)
);

CREATE TABLE prescription_items (
    item_id          SERIAL PRIMARY KEY,
    prescription_id  INT NOT NULL REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    medicine_id      INT NOT NULL REFERENCES medicines(medicine_id),
    dosage           VARCHAR(50) NOT NULL,
    frequency        VARCHAR(30) NOT NULL,
    duration         VARCHAR(30) NOT NULL,
    instructions     VARCHAR(200)
);

CREATE TABLE wards (
    ward_id    SERIAL PRIMARY KEY,
    ward_name  VARCHAR(80) NOT NULL UNIQUE,
    ward_type  VARCHAR(20) NOT NULL
               CHECK (ward_type IN ('GENERAL','ICU','PRIVATE','SEMI_PRIVATE','EMERGENCY','PEDIATRIC','MATERNITY')),
    daily_charge NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (daily_charge >= 0)
);

CREATE TABLE beds (
    bed_id      SERIAL PRIMARY KEY,
    ward_id     INT NOT NULL REFERENCES wards(ward_id) ON DELETE CASCADE,
    bed_number  VARCHAR(10) NOT NULL,
    status      VARCHAR(15) NOT NULL DEFAULT 'AVAILABLE'
                CHECK (status IN ('AVAILABLE','OCCUPIED','RESERVED','MAINTENANCE')),
    UNIQUE (ward_id, bed_number)
);

CREATE TABLE admissions (
    admission_id             SERIAL PRIMARY KEY,
    patient_id               INT NOT NULL REFERENCES patients(patient_id),
    doctor_id                INT NOT NULL REFERENCES doctors(doctor_id),
    bed_id                   INT NOT NULL REFERENCES beds(bed_id),
    admission_date           DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_discharge_date  DATE,
    reason                   TEXT,
    status                   VARCHAR(15) NOT NULL DEFAULT 'ADMITTED'
                             CHECK (status IN ('ADMITTED','DISCHARGED','TRANSFERRED')),
    discharge_date           DATE,
    discharge_diagnosis      TEXT,
    treatment_summary        TEXT,
    doctor_notes             TEXT,
    followup_instructions    TEXT,
    CHECK (expected_discharge_date IS NULL OR expected_discharge_date >= admission_date)
);
-- One active admission per bed and per patient
CREATE UNIQUE INDEX uq_active_bed     ON admissions (bed_id)     WHERE status = 'ADMITTED';
CREATE UNIQUE INDEX uq_active_patient ON admissions (patient_id) WHERE status = 'ADMITTED';

CREATE TABLE bills (
    bill_id        SERIAL PRIMARY KEY,
    patient_id     INT NOT NULL REFERENCES patients(patient_id),
    admission_id   INT REFERENCES admissions(admission_id),
    bill_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    subtotal       NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    discount       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    tax            NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
    grand_total    NUMERIC(12,2) NOT NULL CHECK (grand_total >= 0),
    amount_paid    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
    status         VARCHAR(15) NOT NULL DEFAULT 'PENDING'
                   CHECK (status IN ('PAID','PARTIALLY_PAID','PENDING','REFUNDED')),
    created_by     INT REFERENCES users(user_id),
    CHECK (amount_paid <= grand_total)
);

CREATE TABLE bill_items (
    item_id      SERIAL PRIMARY KEY,
    bill_id      INT NOT NULL REFERENCES bills(bill_id) ON DELETE CASCADE,
    category     VARCHAR(20) NOT NULL
                 CHECK (category IN ('CONSULTATION','ROOM','MEDICINE','LABORATORY','PROCEDURE','OTHER')),
    description  VARCHAR(150) NOT NULL,
    amount       NUMERIC(12,2) NOT NULL CHECK (amount >= 0)
);

CREATE TABLE payments (
    payment_id      SERIAL PRIMARY KEY,
    bill_id         INT NOT NULL REFERENCES bills(bill_id),
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(15) NOT NULL
                    CHECK (payment_method IN ('CASH','CARD','UPI','NET_BANKING','INSURANCE')),
    payment_date    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    received_by     INT REFERENCES users(user_id)
);

CREATE INDEX idx_patients_name     ON patients (last_name, first_name);
CREATE INDEX idx_patients_phone    ON patients (phone);
CREATE INDEX idx_appt_date         ON appointments (appointment_date);
CREATE INDEX idx_appt_patient      ON appointments (patient_id);
CREATE INDEX idx_records_patient   ON medical_records (patient_id, visit_date DESC);
CREATE INDEX idx_rx_patient        ON prescriptions (patient_id);
CREATE INDEX idx_medicine_expiry   ON medicines (expiry_date);
CREATE INDEX idx_bills_patient     ON bills (patient_id);
CREATE INDEX idx_payments_bill     ON payments (bill_id);
