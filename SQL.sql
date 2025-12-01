CREATE DATABASE GOVT_UTILL_6;
USE GOVT_UTILL_6;

/* ===========================
   Utility Management System (Sri Lanka)
   DBMS: Microsoft SQL Server (T-SQL)
   Full Updated Schema Script
   =========================== */


/* ===========================
   1) Master / Reference Tables
   =========================== */

-- ZONE
CREATE TABLE dbo.ZONE (
    zone_id         BIGINT IDENTITY(1,1) NOT NULL,
    zone_name       NVARCHAR(100) NOT NULL,
    region          NVARCHAR(100) NULL,
    office_address  NVARCHAR(255) NULL,
    office_phone    NVARCHAR(30) NULL,
    CONSTRAINT PK_ZONE PRIMARY KEY (zone_id)
);
GO

-- STAFF (Supertype)
CREATE TABLE dbo.STAFF (
    staff_id     BIGINT IDENTITY(1,1) NOT NULL,
    employee_no  NVARCHAR(30) NOT NULL,
    full_name    NVARCHAR(150) NOT NULL,
    phone        NVARCHAR(30) NULL,
    email        NVARCHAR(150) NULL,
    joined_date  DATE NOT NULL,
    status       NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_STAFF PRIMARY KEY (staff_id),
    CONSTRAINT UQ_STAFF_employee_no UNIQUE (employee_no),
    CONSTRAINT CK_STAFF_status CHECK (status IN ('Active','OnLeave','Resigned'))
);
GO

/* ===========================
   2) Staff Subtype Tables (EER Disjoint)
   Note: disjointness across subtype tables
   is typically enforced via app logic or triggers.
   =========================== */

CREATE TABLE dbo.ADMINISTRATIVE_STAFF (
    staff_id                 BIGINT NOT NULL,
    department               NVARCHAR(60) NOT NULL,
    can_manage_tariffs       BIT NOT NULL,
    can_register_connections BIT NOT NULL,
    shift_type               NVARCHAR(20) NULL,
    CONSTRAINT PK_ADMINISTRATIVE_STAFF PRIMARY KEY (staff_id),
    CONSTRAINT FK_ADMINISTRATIVE_STAFF_STAFF FOREIGN KEY (staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_ADMINISTRATIVE_STAFF_shift CHECK (shift_type IS NULL OR shift_type IN ('Day','Night','Rotational'))
);
GO

CREATE TABLE dbo.METER_READER (
    staff_id    BIGINT NOT NULL,
    device_id   NVARCHAR(60) NULL,
    route_code  NVARCHAR(40) NULL,
    CONSTRAINT PK_METER_READER PRIMARY KEY (staff_id),
    CONSTRAINT FK_METER_READER_STAFF FOREIGN KEY (staff_id) REFERENCES dbo.STAFF(staff_id)
);
GO

CREATE TABLE dbo.FIELD_OFFICER (
    staff_id              BIGINT NOT NULL,
    route_code            NVARCHAR(40) NULL,
    certification_level   NVARCHAR(30) NULL,
    shift_type            NVARCHAR(20) NULL,
    vehicle_no            NVARCHAR(30) NULL,
    CONSTRAINT PK_FIELD_OFFICER PRIMARY KEY (staff_id),
    CONSTRAINT FK_FIELD_OFFICER_STAFF FOREIGN KEY (staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_FIELD_OFFICER_shift CHECK (shift_type IS NULL OR shift_type IN ('Day','Night','Rotational'))
);
GO

CREATE TABLE dbo.CASHIER (
    staff_id        BIGINT NOT NULL,
    counter_no      NVARCHAR(20) NULL,
    cash_drawer_id  NVARCHAR(30) NULL,
    shift_type      NVARCHAR(20) NULL,
    CONSTRAINT PK_CASHIER PRIMARY KEY (staff_id),
    CONSTRAINT FK_CASHIER_STAFF FOREIGN KEY (staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_CASHIER_shift CHECK (shift_type IS NULL OR shift_type IN ('Day','Night','Rotational'))
);
GO

CREATE TABLE dbo.MANAGER (
    staff_id              BIGINT NOT NULL,
    management_level      NVARCHAR(30) NULL,
    approval_limit_amount DECIMAL(18,2) NULL,
    report_access_level   NVARCHAR(30) NULL,
    CONSTRAINT PK_MANAGER PRIMARY KEY (staff_id),
    CONSTRAINT FK_MANAGER_STAFF FOREIGN KEY (staff_id) REFERENCES dbo.STAFF(staff_id)
);
GO

/* ===========================
   3) Customer + Tariff
   =========================== */

-- CUSTOMER
-- (Customer zone = home/mailing zone; connection zone = premises zone for reporting)
CREATE TABLE dbo.CUSTOMER (
    customer_id        BIGINT IDENTITY(1,1) NOT NULL,
    zone_id            BIGINT NOT NULL,
    full_name          NVARCHAR(150) NOT NULL,
    identity_type      NVARCHAR(20) NOT NULL,
    identity_ref       NVARCHAR(30) NULL,
    phone              NVARCHAR(30) NULL,
    email              NVARCHAR(150) NULL,
    address_line1      NVARCHAR(150) NOT NULL,
    address_line2      NVARCHAR(150) NULL,
    city               NVARCHAR(80) NOT NULL,
    postal_code        NVARCHAR(20) NULL,
    registration_date  DATE NOT NULL,
    status             NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_CUSTOMER PRIMARY KEY (customer_id),
    CONSTRAINT FK_CUSTOMER_ZONE FOREIGN KEY (zone_id) REFERENCES dbo.ZONE(zone_id),
    CONSTRAINT CK_CUSTOMER_status CHECK (status IN ('Active','Suspended','Closed')),
    CONSTRAINT CK_CUSTOMER_identity_type CHECK (identity_type IN ('NIC','Passport','BRN','Other'))
);
GO

-- Unique identity (only when identity_ref is provided)
CREATE UNIQUE INDEX UX_CUSTOMER_identity
ON dbo.CUSTOMER(identity_type, identity_ref)
WHERE identity_ref IS NOT NULL;
GO

-- TARIFF_CATEGORY
CREATE TABLE dbo.TARIFF_CATEGORY (
    tariff_category_id BIGINT IDENTITY(1,1) NOT NULL,
    utility_type       NVARCHAR(20) NOT NULL,
    code               NVARCHAR(20) NOT NULL,
    name               NVARCHAR(100) NOT NULL,
    description        NVARCHAR(255) NULL,
    is_subsidized      BIT NOT NULL,
    CONSTRAINT PK_TARIFF_CATEGORY PRIMARY KEY (tariff_category_id),
    CONSTRAINT CK_TARIFF_CATEGORY_utility CHECK (utility_type IN ('Electricity','Water','Gas'))
);
GO

-- TARIFF_SLAB
CREATE TABLE dbo.TARIFF_SLAB (
    slab_id            BIGINT IDENTITY(1,1) NOT NULL,
    tariff_category_id BIGINT NOT NULL,
    valid_from         DATE NOT NULL,
    valid_to           DATE NULL,
    min_units          INT NOT NULL,
    max_units          INT NULL,
    unit_price         DECIMAL(18,2) NOT NULL,
    fixed_charge       DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_TARIFF_SLAB PRIMARY KEY (slab_id),
    CONSTRAINT FK_TARIFF_SLAB_CATEGORY FOREIGN KEY (tariff_category_id) REFERENCES dbo.TARIFF_CATEGORY(tariff_category_id),
    CONSTRAINT CK_TARIFF_SLAB_units CHECK (min_units >= 0 AND (max_units IS NULL OR max_units >= min_units)),
    CONSTRAINT CK_TARIFF_SLAB_dates CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO

/* ===========================
   4) Connection + Meter + Solar
   =========================== */

-- CONNECTION (UPDATED: zone_id added for premises-based reporting)
CREATE TABLE dbo._CONNECTION (
    connection_id      BIGINT IDENTITY(1,1) NOT NULL,
    customer_id        BIGINT NOT NULL,
    zone_id            BIGINT NOT NULL,  -- ✅ premises zone
    utility_type       NVARCHAR(20) NOT NULL,
    service_address    NVARCHAR(255) NOT NULL,
    tariff_category_id BIGINT NOT NULL,
    connection_status  NVARCHAR(50) NOT NULL,
    start_date         DATE NOT NULL,
    end_date           DATE NULL,
    CONSTRAINT PK_CONNECTION PRIMARY KEY (connection_id),
    CONSTRAINT FK_CONNECTION_CUSTOMER FOREIGN KEY (customer_id) REFERENCES dbo.CUSTOMER(customer_id),
    CONSTRAINT FK_CONNECTION_ZONE FOREIGN KEY (zone_id) REFERENCES dbo.ZONE(zone_id),
    CONSTRAINT FK_CONNECTION_TARIFF_CATEGORY FOREIGN KEY (tariff_category_id) REFERENCES dbo.TARIFF_CATEGORY(tariff_category_id),
    CONSTRAINT CK_CONNECTION_utility CHECK (utility_type IN ('Electricity','Water','Gas')),
    CONSTRAINT CK_CONNECTION_status CHECK (connection_status IN (
        'Active','Suspended','Closed','Pending',
        'Temporary_Disconnected','Awaiting_Approval','Pending_Investigation'
    )),
    CONSTRAINT CK_CONNECTION_dates CHECK (end_date IS NULL OR end_date >= start_date)
);
GO

-- Index for zone-based reporting
CREATE INDEX IX_CONNECTION_zone_utility
ON dbo._CONNECTION(zone_id, utility_type);
GO

-- METER
CREATE TABLE dbo.METER (
    meter_id        BIGINT IDENTITY(1,1) NOT NULL,
    connection_id   BIGINT NOT NULL,
    meter_serial_no NVARCHAR(60) NOT NULL,
    meter_type      NVARCHAR(20) NOT NULL,
    meter_role      NVARCHAR(25) NOT NULL,
    installed_from  DATE NOT NULL,
    removed_at      DATE NULL,
    status          NVARCHAR(50) NOT NULL,
    is_smart_meter  BIT NOT NULL,
    CONSTRAINT PK_METER PRIMARY KEY (meter_id),
    CONSTRAINT FK_METER_CONNECTION FOREIGN KEY (connection_id) REFERENCES dbo._CONNECTION(connection_id),
    CONSTRAINT UQ_METER_serial UNIQUE (meter_serial_no),
    CONSTRAINT CK_METER_type CHECK (meter_type IN ('Postpaid','Prepaid')),
    CONSTRAINT CK_METER_role CHECK (meter_role IN ('Standard','Net_Meter','Generation_Only')),
    CONSTRAINT CK_METER_status CHECK (status IN ('Active','Removed','Faulty')),
    CONSTRAINT CK_METER_dates CHECK (removed_at IS NULL OR removed_at >= installed_from)
);
GO

-- Enforce: only ONE Active meter per connection
CREATE UNIQUE INDEX UX_METER_one_active_per_connection
ON dbo.METER(connection_id)
WHERE status = 'Active';
GO

-- SOLAR_INSTALLATION (linked to CONNECTION to preserve history across meter replacements)
CREATE TABLE dbo.SOLAR_INSTALLATION (
    solar_id              BIGINT IDENTITY(1,1) NOT NULL,
    connection_id         BIGINT NOT NULL,
    installed_capacity_kw DECIMAL(6,2) NOT NULL,
    scheme_type           NVARCHAR(30) NOT NULL,
    approval_ref          NVARCHAR(60) NULL,
    agreement_start_date  DATE NOT NULL,
    agreement_end_date    DATE NULL,
    status                NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_SOLAR_INSTALLATION PRIMARY KEY (solar_id),
    CONSTRAINT FK_SOLAR_INSTALLATION_CONNECTION FOREIGN KEY (connection_id) REFERENCES dbo._CONNECTION(connection_id),
    CONSTRAINT UQ_SOLAR_installation_per_connection UNIQUE (connection_id),
    CONSTRAINT CK_SOLAR_scheme CHECK (scheme_type IN ('Net_Metering','Net_Accounting','Net_Plus')),
    CONSTRAINT CK_SOLAR_status CHECK (status IN ('Active','Inactive','Decommissioned')),
    CONSTRAINT CK_SOLAR_dates CHECK (agreement_end_date IS NULL OR agreement_end_date >= agreement_start_date)
);
GO

/* ===========================
   5) Operations: Readings, Billing, Payments, Subsidies, Taxes
   =========================== */

-- METER_READING
CREATE TABLE dbo.METER_READING (
    reading_id           BIGINT IDENTITY(1,1) NOT NULL,
    meter_id             BIGINT NOT NULL,
    reading_date         DATE NOT NULL,
    import_reading       DECIMAL(12,3) NOT NULL,
    export_reading       DECIMAL(12,3) NULL,
    reading_source       NVARCHAR(20) NOT NULL,
    captured_by_staff_id BIGINT NOT NULL,
    CONSTRAINT PK_METER_READING PRIMARY KEY (reading_id),
    CONSTRAINT FK_METER_READING_METER FOREIGN KEY (meter_id) REFERENCES dbo.METER(meter_id),
    CONSTRAINT FK_METER_READING_STAFF FOREIGN KEY (captured_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_METER_READING_source CHECK (reading_source IN ('Manual','Mobile_App','Smart_Meter','Estimated','Adjusted')),
    CONSTRAINT CK_METER_READING_values CHECK (import_reading >= 0 AND (export_reading IS NULL OR export_reading >= 0))
);
GO

-- BILL
CREATE TABLE dbo.BILL (
    bill_id               BIGINT IDENTITY(1,1) NOT NULL,
    connection_id         BIGINT NOT NULL,
    meter_id              BIGINT NULL,
    billing_period_start  DATE NOT NULL,
    billing_period_end    DATE NOT NULL,
    bill_date             DATE NOT NULL,
    due_date              DATE NOT NULL,
    total_import_units    DECIMAL(12,3) NOT NULL,
    total_export_units    DECIMAL(12,3) NULL,
    energy_charge_amount  DECIMAL(18,2) NOT NULL,
    fixed_charge_amount   DECIMAL(18,2) NOT NULL,
    subsidy_amount        DECIMAL(18,2) NOT NULL,
    solar_export_credit   DECIMAL(18,2) NOT NULL,
    tax_total_amount      DECIMAL(18,2) NOT NULL,
    net_amount            DECIMAL(18,2) NOT NULL,
    status                NVARCHAR(50) NOT NULL,
    generated_by_staff_id BIGINT NULL,
    CONSTRAINT PK_BILL PRIMARY KEY (bill_id),
    CONSTRAINT FK_BILL_CONNECTION FOREIGN KEY (connection_id) REFERENCES dbo._CONNECTION(connection_id),
    CONSTRAINT FK_BILL_METER FOREIGN KEY (meter_id) REFERENCES dbo.METER(meter_id),
    CONSTRAINT FK_BILL_STAFF FOREIGN KEY (generated_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_BILL_status CHECK (status IN ('Pending','Partially_Paid','Paid','Cancelled')),
    CONSTRAINT CK_BILL_dates CHECK (billing_period_end >= billing_period_start AND due_date >= bill_date),
    CONSTRAINT CK_BILL_amounts CHECK (
        energy_charge_amount >= 0 AND fixed_charge_amount >= 0 AND subsidy_amount >= 0
        AND solar_export_credit >= 0 AND tax_total_amount >= 0 AND net_amount >= 0
    )
);
GO

-- BILL_DETAIL
CREATE TABLE dbo.BILL_DETAIL (
    bill_detail_id BIGINT IDENTITY(1,1) NOT NULL,
    bill_id        BIGINT NOT NULL,
    slab_id        BIGINT NOT NULL,
    units_in_slab  DECIMAL(12,3) NOT NULL,
    amount         DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_BILL_DETAIL PRIMARY KEY (bill_detail_id),
    CONSTRAINT FK_BILL_DETAIL_BILL FOREIGN KEY (bill_id) REFERENCES dbo.BILL(bill_id),
    CONSTRAINT FK_BILL_DETAIL_SLAB FOREIGN KEY (slab_id) REFERENCES dbo.TARIFF_SLAB(slab_id),
    CONSTRAINT CK_BILL_DETAIL_values CHECK (units_in_slab >= 0 AND amount >= 0)
);
GO

-- PAYMENT
CREATE TABLE dbo.PAYMENT (
    payment_id           BIGINT IDENTITY(1,1) NOT NULL,
    bill_id              BIGINT NOT NULL,
    payment_date         DATETIME2(0) NOT NULL,
    payment_amount       DECIMAL(18,2) NOT NULL,
    payment_method       NVARCHAR(20) NOT NULL,
    payment_channel      NVARCHAR(30) NULL,
    transaction_ref      NVARCHAR(80) NULL,
    recorded_by_staff_id BIGINT NOT NULL,
    CONSTRAINT PK_PAYMENT PRIMARY KEY (payment_id),
    CONSTRAINT FK_PAYMENT_BILL FOREIGN KEY (bill_id) REFERENCES dbo.BILL(bill_id),
    CONSTRAINT FK_PAYMENT_STAFF FOREIGN KEY (recorded_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_PAYMENT_method CHECK (payment_method IN ('Cash','Card','Online','Bank','QR')),
    CONSTRAINT CK_PAYMENT_amount CHECK (payment_amount > 0)
);
GO

-- SUBSIDY_SCHEME
CREATE TABLE dbo.SUBSIDY_SCHEME (
    subsidy_id     BIGINT IDENTITY(1,1) NOT NULL,
    name           NVARCHAR(120) NOT NULL,
    discount_type  NVARCHAR(20) NOT NULL,
    discount_value DECIMAL(18,2) NOT NULL,
    valid_from     DATE NOT NULL,
    valid_to       DATE NULL,
    description    NVARCHAR(255) NULL,
    CONSTRAINT PK_SUBSIDY_SCHEME PRIMARY KEY (subsidy_id),
    CONSTRAINT CK_SUBSIDY_discount_type CHECK (discount_type IN ('Percentage','Fixed')),
    CONSTRAINT CK_SUBSIDY_dates CHECK (valid_to IS NULL OR valid_to >= valid_from),
    CONSTRAINT CK_SUBSIDY_value CHECK (discount_value >= 0)
);
GO

-- CUSTOMER_SUBSIDY
CREATE TABLE dbo.CUSTOMER_SUBSIDY (
    customer_subsidy_id  BIGINT IDENTITY(1,1) NOT NULL,
    customer_id          BIGINT NOT NULL,
    subsidy_id           BIGINT NOT NULL,
    approved_by_staff_id BIGINT NOT NULL,
    approved_date        DATE NOT NULL,
    status               NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_CUSTOMER_SUBSIDY PRIMARY KEY (customer_subsidy_id),
    CONSTRAINT FK_CUSTOMER_SUBSIDY_CUSTOMER FOREIGN KEY (customer_id) REFERENCES dbo.CUSTOMER(customer_id),
    CONSTRAINT FK_CUSTOMER_SUBSIDY_SCHEME FOREIGN KEY (subsidy_id) REFERENCES dbo.SUBSIDY_SCHEME(subsidy_id),
    CONSTRAINT FK_CUSTOMER_SUBSIDY_STAFF FOREIGN KEY (approved_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_CUSTOMER_SUBSIDY_status CHECK (status IN ('Active','Expired','Cancelled','Pending','Awaiting_Approval'))
);
GO

-- TAX_CONFIG
CREATE TABLE dbo.TAX_CONFIG (
    tax_id              BIGINT IDENTITY(1,1) NOT NULL,
    tax_name            NVARCHAR(50) NOT NULL,
    rate_percent        DECIMAL(6,3) NOT NULL,
    effective_from      DATE NOT NULL,
    effective_to        DATE NULL,
    status              NVARCHAR(50) NOT NULL,
    created_by_staff_id BIGINT NOT NULL,
    created_at          DATETIME2(0) NOT NULL,
    CONSTRAINT PK_TAX_CONFIG PRIMARY KEY (tax_id),
    CONSTRAINT FK_TAX_CONFIG_STAFF FOREIGN KEY (created_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_TAX_CONFIG_status CHECK (status IN ('Active','Inactive')),
    CONSTRAINT CK_TAX_CONFIG_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT CK_TAX_CONFIG_rate CHECK (rate_percent >= 0 AND rate_percent <= 100)
);
GO

-- BILL_TAX
CREATE TABLE dbo.BILL_TAX (
    bill_tax_id          BIGINT IDENTITY(1,1) NOT NULL,
    bill_id              BIGINT NOT NULL,
    tax_id               BIGINT NOT NULL,
    rate_percent_applied DECIMAL(6,3) NOT NULL,
    taxable_base_amount  DECIMAL(18,2) NOT NULL,
    tax_amount           DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_BILL_TAX PRIMARY KEY (bill_tax_id),
    CONSTRAINT FK_BILL_TAX_BILL FOREIGN KEY (bill_id) REFERENCES dbo.BILL(bill_id),
    CONSTRAINT FK_BILL_TAX_TAX FOREIGN KEY (tax_id) REFERENCES dbo.TAX_CONFIG(tax_id),
    CONSTRAINT CK_BILL_TAX_rate CHECK (rate_percent_applied >= 0 AND rate_percent_applied <= 100),
    CONSTRAINT CK_BILL_TAX_amounts CHECK (taxable_base_amount >= 0 AND tax_amount >= 0)
);
GO

/* ===========================
   6) Customer Service + Network Ops
   =========================== */

-- COMPLAINT
CREATE TABLE dbo.COMPLAINT (
    complaint_id        BIGINT IDENTITY(1,1) NOT NULL,
    customer_id         BIGINT NOT NULL,
    connection_id       BIGINT NULL,
    meter_id            BIGINT NULL,
    complaint_type      NVARCHAR(30) NOT NULL,
    description         NVARCHAR(500) NULL,
    created_date        DATETIME2(0) NOT NULL,
    status              NVARCHAR(50) NOT NULL,
    logged_by_staff_id  BIGINT NOT NULL,
    assigned_staff_id   BIGINT NULL,
    resolved_date       DATETIME2(0) NULL,
    CONSTRAINT PK_COMPLAINT PRIMARY KEY (complaint_id),
    CONSTRAINT FK_COMPLAINT_CUSTOMER FOREIGN KEY (customer_id) REFERENCES dbo.CUSTOMER(customer_id),
    CONSTRAINT FK_COMPLAINT_CONNECTION FOREIGN KEY (connection_id) REFERENCES dbo._CONNECTION(connection_id),
    CONSTRAINT FK_COMPLAINT_METER FOREIGN KEY (meter_id) REFERENCES dbo.METER(meter_id),
    CONSTRAINT FK_COMPLAINT_LOGGED_BY FOREIGN KEY (logged_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT FK_COMPLAINT_ASSIGNED_TO FOREIGN KEY (assigned_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_COMPLAINT_status CHECK (status IN ('Open','In_Progress','Resolved','Closed','Pending_Investigation'))
);
GO

-- OUTAGE (zone-based)
CREATE TABLE dbo.OUTAGE (
    outage_id           BIGINT IDENTITY(1,1) NOT NULL,
    zone_id             BIGINT NOT NULL,
    utility_type        NVARCHAR(20) NOT NULL,
    outage_type         NVARCHAR(20) NOT NULL,
    start_time          DATETIME2(0) NOT NULL,
    end_time            DATETIME2(0) NULL,
    reason              NVARCHAR(255) NULL,
    created_by_staff_id BIGINT NOT NULL,
    CONSTRAINT PK_OUTAGE PRIMARY KEY (outage_id),
    CONSTRAINT FK_OUTAGE_ZONE FOREIGN KEY (zone_id) REFERENCES dbo.ZONE(zone_id),
    CONSTRAINT FK_OUTAGE_STAFF FOREIGN KEY (created_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_OUTAGE_utility CHECK (utility_type IN ('Electricity','Water','Gas')),
    CONSTRAINT CK_OUTAGE_type CHECK (outage_type IN ('Planned','Unplanned')),
    CONSTRAINT CK_OUTAGE_dates CHECK (end_time IS NULL OR end_time >= start_time)
);
GO

-- DISCONNECTION_ORDER
CREATE TABLE dbo.DISCONNECTION_ORDER (
    disconnection_id     BIGINT IDENTITY(1,1) NOT NULL,
    meter_id             BIGINT NOT NULL,
    reason               NVARCHAR(40) NOT NULL,
    issue_date           DATE NOT NULL,
    scheduled_date       DATE NOT NULL,
    executed_date        DATE NULL,
    status               NVARCHAR(50) NOT NULL,
    created_by_staff_id  BIGINT NOT NULL,
    executed_by_staff_id BIGINT NULL,
    CONSTRAINT PK_DISCONNECTION_ORDER PRIMARY KEY (disconnection_id),
    CONSTRAINT FK_DISCONNECTION_METER FOREIGN KEY (meter_id) REFERENCES dbo.METER(meter_id),
    CONSTRAINT FK_DISCONNECTION_CREATED_BY FOREIGN KEY (created_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT FK_DISCONNECTION_EXECUTED_BY FOREIGN KEY (executed_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_DISCONNECTION_reason CHECK (reason IN ('Non_Payment','Fraud','Customer_Request','Safety')),
    CONSTRAINT CK_DISCONNECTION_status CHECK (status IN ('Pending','Completed','Cancelled')),
    CONSTRAINT CK_DISCONNECTION_dates CHECK (executed_date IS NULL OR executed_date >= issue_date)
);
GO

-- RECONNECTION
CREATE TABLE dbo.RECONNECTION (
    reconnection_id       BIGINT IDENTITY(1,1) NOT NULL,
    meter_id              BIGINT NOT NULL,
    reconnection_date     DATE NOT NULL,
    reconnection_fee      DECIMAL(18,2) NOT NULL,
    processed_by_staff_id BIGINT NOT NULL,
    CONSTRAINT PK_RECONNECTION PRIMARY KEY (reconnection_id),
    CONSTRAINT FK_RECONNECTION_METER FOREIGN KEY (meter_id) REFERENCES dbo.METER(meter_id),
    CONSTRAINT FK_RECONNECTION_STAFF FOREIGN KEY (processed_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_RECONNECTION_fee CHECK (reconnection_fee >= 0)
);
GO

/* ===========================
   7) Reporting
   =========================== */

-- REPORT_REQUEST
CREATE TABLE dbo.REPORT_REQUEST (
    report_request_id     BIGINT IDENTITY(1,1) NOT NULL,
    requested_by_staff_id BIGINT NOT NULL,
    requested_at          DATETIME2(0) NOT NULL,
    report_type           NVARCHAR(50) NOT NULL,
    params_json           NVARCHAR(MAX) NULL,
    CONSTRAINT PK_REPORT_REQUEST PRIMARY KEY (report_request_id),
    CONSTRAINT FK_REPORT_REQUEST_STAFF FOREIGN KEY (requested_by_staff_id) REFERENCES dbo.STAFF(staff_id),
    CONSTRAINT CK_REPORT_REQUEST_params_json CHECK (params_json IS NULL OR ISJSON(params_json) = 1)
);
GO







CREATE OR ALTER FUNCTION dbo.fn_BillOutstandingAmount
(
    @bill_id BIGINT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @net DECIMAL(18,2) = (SELECT net_amount FROM dbo.BILL WHERE bill_id = @bill_id);
    DECLARE @paid DECIMAL(18,2) =
        ISNULL((SELECT SUM(payment_amount) FROM dbo.PAYMENT WHERE bill_id = @bill_id), 0);

    RETURN CASE
        WHEN @net IS NULL THEN 0
        WHEN (@net - @paid) < 0 THEN 0
        ELSE (@net - @paid)
    END;
END;
GO



CREATE OR ALTER FUNCTION dbo.fn_CalcLateFee
(
    @bill_id BIGINT,
    @as_of_date DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @due DATE = (SELECT due_date FROM dbo.BILL WHERE bill_id = @bill_id);
    DECLARE @outstanding DECIMAL(18,2) = dbo.fn_BillOutstandingAmount(@bill_id);

    IF @due IS NULL OR @as_of_date <= @due OR @outstanding <= 0
        RETURN 0;

    DECLARE @days_late INT = DATEDIFF(DAY, @due, @as_of_date);
    DECLARE @daily_rate DECIMAL(18,8) = (0.02 / 30.0); -- 2% per month approximated

    RETURN ROUND(@outstanding * @daily_rate * @days_late, 2);
END;
GO



CREATE OR ALTER FUNCTION dbo.fn_CalcEnergyCharge
(
    @tariff_category_id BIGINT,
    @units DECIMAL(12,3),
    @as_of_date DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @u DECIMAL(12,3) = CASE WHEN @units < 0 THEN 0 ELSE @units END;

    RETURN ISNULL((
        SELECT SUM(
            CAST(
                CASE
                    WHEN @u <= s.min_units THEN 0
                    ELSE
                        (
                            CASE
                                WHEN s.max_units IS NULL THEN (@u - s.min_units)
                                WHEN @u >= s.max_units THEN (s.max_units - s.min_units)
                                ELSE (@u - s.min_units)
                            END
                        ) * s.unit_price
                END
            AS DECIMAL(18,2))
        )
        FROM dbo.TARIFF_SLAB s
        WHERE s.tariff_category_id = @tariff_category_id
          AND s.valid_from <= @as_of_date
          AND (s.valid_to IS NULL OR s.valid_to >= @as_of_date)
    ), 0);
END;
GO




CREATE OR ALTER VIEW dbo.vw_BillPaymentSummary
AS
SELECT
    b.bill_id,
    b.connection_id,
    b.bill_date,
    b.due_date,
    b.net_amount,
    ISNULL(p.paid_amount, 0) AS paid_amount,
    CASE
        WHEN b.net_amount - ISNULL(p.paid_amount, 0) < 0 THEN 0
        ELSE (b.net_amount - ISNULL(p.paid_amount, 0))
    END AS outstanding_amount,
    p.last_payment_date
FROM dbo.BILL b
OUTER APPLY (
    SELECT
        SUM(payment_amount) AS paid_amount,
        MAX(payment_date) AS last_payment_date
    FROM dbo.PAYMENT p
    WHERE p.bill_id = b.bill_id
) p;
GO


CREATE OR ALTER VIEW dbo.vw_UnpaidBills
AS
SELECT
    z.zone_name,
    c.utility_type,
    cu.customer_id,
    cu.full_name AS customer_name,
    con.connection_id,
    b.bill_id,
    b.bill_date,
    b.due_date,
    b.net_amount,
    s.paid_amount,
    s.outstanding_amount,
    b.status
FROM dbo.BILL b
JOIN dbo.vw_BillPaymentSummary s ON s.bill_id = b.bill_id
JOIN dbo._CONNECTION con ON con.connection_id = b.connection_id
JOIN dbo.CUSTOMER cu ON cu.customer_id = con.customer_id
JOIN dbo.ZONE z ON z.zone_id = con.zone_id
JOIN dbo.TARIFF_CATEGORY c ON c.tariff_category_id = con.tariff_category_id
WHERE s.outstanding_amount > 0
  AND b.status IN ('Pending','Partially_Paid');
GO




CREATE OR ALTER VIEW dbo.vw_MonthlyRevenue
AS
SELECT
    con.zone_id,
    z.zone_name,
    con.utility_type,
    DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1) AS revenue_month,
    SUM(p.payment_amount) AS total_revenue
FROM dbo.PAYMENT p
JOIN dbo.BILL b ON b.bill_id = p.bill_id
JOIN dbo._CONNECTION con ON con.connection_id = b.connection_id
JOIN dbo.ZONE z ON z.zone_id = con.zone_id
GROUP BY
    con.zone_id, z.zone_name, con.utility_type,
    DATEFROMPARTS(YEAR(p.payment_date), MONTH(p.payment_date), 1);
GO



CREATE OR ALTER TRIGGER dbo.trg_PAYMENT_UpdateBillStatus
ON dbo.PAYMENT
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedBills AS (
        SELECT bill_id FROM inserted
        UNION
        SELECT bill_id FROM deleted
    ),
    Sums AS (
        SELECT
            b.bill_id,
            b.net_amount,
            ISNULL(SUM(p.payment_amount), 0) AS paid_amount
        FROM dbo.BILL b
        JOIN ChangedBills cb ON cb.bill_id = b.bill_id
        LEFT JOIN dbo.PAYMENT p ON p.bill_id = b.bill_id
        GROUP BY b.bill_id, b.net_amount
    )
    UPDATE b
    SET b.status =
        CASE
            WHEN s.paid_amount <= 0 THEN 'Pending'
            WHEN s.paid_amount >= s.net_amount THEN 'Paid'
            ELSE 'Partially_Paid'
        END
    FROM dbo.BILL b
    JOIN Sums s ON s.bill_id = b.bill_id
    WHERE b.status <> 'Cancelled';
END;
GO













CREATE OR ALTER TRIGGER dbo.trg_BILL_TAX_UpdateBillTotals
ON dbo.BILL_TAX
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedBills AS (
        SELECT bill_id FROM inserted
        UNION
        SELECT bill_id FROM deleted
    ),
    TaxSum AS (
        SELECT
            b.bill_id,
            ISNULL(SUM(bt.tax_amount), 0) AS tax_total
        FROM dbo.BILL b
        JOIN ChangedBills cb ON cb.bill_id = b.bill_id
        LEFT JOIN dbo.BILL_TAX bt ON bt.bill_id = b.bill_id
        GROUP BY b.bill_id
    )
    UPDATE b
    SET
        b.tax_total_amount = t.tax_total,
        b.net_amount = ROUND(
            (b.energy_charge_amount + b.fixed_charge_amount - b.subsidy_amount - b.solar_export_credit + t.tax_total),
            2
        )
    FROM dbo.BILL b
    JOIN TaxSum t ON t.bill_id = b.bill_id
    WHERE b.status <> 'Cancelled';
END;
GO





CREATE OR ALTER PROCEDURE dbo.sp_GenerateBillForConnection
    @connection_id BIGINT,
    @billing_period_start DATE,
    @billing_period_end DATE,
    @bill_date DATE,
    @due_date DATE,
    @generated_by_staff_id BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE @tariff_category_id BIGINT;
    DECLARE @customer_id BIGINT;
    DECLARE @meter_id BIGINT;

    SELECT
        @tariff_category_id = tariff_category_id,
        @customer_id = customer_id
    FROM dbo._CONNECTION
    WHERE connection_id = @connection_id;

    IF @tariff_category_id IS NULL
        THROW 50001, 'Invalid connection_id (tariff_category_id not found).', 1;

    SELECT TOP (1) @meter_id = meter_id
    FROM dbo.METER
    WHERE connection_id = @connection_id
      AND status = 'Active'
    ORDER BY installed_from DESC;

    IF @meter_id IS NULL
        THROW 50002, 'No active meter found for this connection.', 1;

    DECLARE @prev_import DECIMAL(12,3);
    DECLARE @curr_import DECIMAL(12,3);

    SELECT TOP (1) @prev_import = import_reading
    FROM dbo.METER_READING
    WHERE meter_id = @meter_id
      AND reading_date < @billing_period_start
    ORDER BY reading_date DESC;

    SELECT TOP (1) @curr_import = import_reading
    FROM dbo.METER_READING
    WHERE meter_id = @meter_id
      AND reading_date <= @billing_period_end
    ORDER BY reading_date DESC;

    IF @prev_import IS NULL OR @curr_import IS NULL
        THROW 50003, 'Missing meter readings for billing period (need previous and current).', 1;

    DECLARE @units DECIMAL(12,3) = @curr_import - @prev_import;
    IF @units < 0
        THROW 50004, 'Meter readings invalid (current reading less than previous).', 1;

    DECLARE @energy_charge DECIMAL(18,2) = dbo.fn_CalcEnergyCharge(@tariff_category_id, @units, @bill_date);

    -- Fixed charge rule (simple): max fixed_charge among effective slabs
    DECLARE @fixed_charge DECIMAL(18,2) =
        ISNULL((
            SELECT MAX(fixed_charge)
            FROM dbo.TARIFF_SLAB
            WHERE tariff_category_id = @tariff_category_id
              AND valid_from <= @bill_date
              AND (valid_to IS NULL OR valid_to >= @bill_date)
        ), 0);

    -- Solar export credit (not modeled with rates here => keep 0; can be extended later)
    DECLARE @solar_credit DECIMAL(18,2) = 0;

    -- Subsidy
    DECLARE @subsidy DECIMAL(18,2) = 0;

    ;WITH ActiveSub AS (
        SELECT TOP (1)
            ss.discount_type,
            ss.discount_value
        FROM dbo.CUSTOMER_SUBSIDY cs
        JOIN dbo.SUBSIDY_SCHEME ss ON ss.subsidy_id = cs.subsidy_id
        WHERE cs.customer_id = @customer_id
          AND cs.status = 'Active'
          AND ss.valid_from <= @bill_date
          AND (ss.valid_to IS NULL OR ss.valid_to >= @bill_date)
        ORDER BY ss.valid_from DESC
    )
    SELECT @subsidy =
        CASE
            WHEN discount_type = 'Percentage' THEN ROUND((@energy_charge + @fixed_charge) * (discount_value / 100.0), 2)
            WHEN discount_type = 'Fixed' THEN ROUND(discount_value, 2)
            ELSE 0
        END
    FROM ActiveSub;

    DECLARE @tax_total DECIMAL(18,2) = 0;
    DECLARE @net_amount DECIMAL(18,2) = 0;

    -- Create the bill (tax_total/net recalculated after inserting BILL_TAX)
    INSERT INTO dbo.BILL (
        connection_id, meter_id, billing_period_start, billing_period_end,
        bill_date, due_date,
        total_import_units, total_export_units,
        energy_charge_amount, fixed_charge_amount,
        subsidy_amount, solar_export_credit,
        tax_total_amount, net_amount,
        status, generated_by_staff_id
    )
    VALUES (
        @connection_id, @meter_id, @billing_period_start, @billing_period_end,
        @bill_date, @due_date,
        @units, NULL,
        @energy_charge, @fixed_charge,
        @subsidy, @solar_credit,
        0, 0,
        'Pending', @generated_by_staff_id
    );

    DECLARE @bill_id BIGINT = SCOPE_IDENTITY();

    -- Insert taxes applied (all active taxes)
    DECLARE @taxable_base DECIMAL(18,2) = (@energy_charge + @fixed_charge - @subsidy - @solar_credit);
    IF @taxable_base < 0 SET @taxable_base = 0;

    INSERT INTO dbo.BILL_TAX (bill_id, tax_id, rate_percent_applied, taxable_base_amount, tax_amount)
    SELECT
        @bill_id,
        t.tax_id,
        t.rate_percent,
        @taxable_base,
        ROUND(@taxable_base * (t.rate_percent / 100.0), 2)
    FROM dbo.TAX_CONFIG t
    WHERE t.status = 'Active'
      AND t.effective_from <= @bill_date
      AND (t.effective_to IS NULL OR t.effective_to >= @bill_date);

    -- Tax trigger will update BILL.tax_total_amount and BILL.net_amount automatically
    -- But ensure net is correct even if no taxes exist:
    IF NOT EXISTS (SELECT 1 FROM dbo.BILL_TAX WHERE bill_id = @bill_id)
    BEGIN
        UPDATE dbo.BILL
        SET tax_total_amount = 0,
            net_amount = ROUND(@energy_charge + @fixed_charge - @subsidy - @solar_credit, 2)
        WHERE bill_id = @bill_id;
    END

    COMMIT;
END;
GO








CREATE OR ALTER PROCEDURE dbo.sp_ListDefaulters
    @as_of_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        z.zone_name,
        con.utility_type,
        cu.customer_id,
        cu.full_name AS customer_name,
        con.connection_id,
        b.bill_id,
        b.due_date,
        s.outstanding_amount,
        dbo.fn_CalcLateFee(b.bill_id, @as_of_date) AS late_fee_estimate
    FROM dbo.BILL b
    JOIN dbo.vw_BillPaymentSummary s ON s.bill_id = b.bill_id
    JOIN dbo._CONNECTION con ON con.connection_id = b.connection_id
    JOIN dbo.CUSTOMER cu ON cu.customer_id = con.customer_id
    JOIN dbo.ZONE z ON z.zone_id = con.zone_id
    WHERE b.due_date < @as_of_date
      AND s.outstanding_amount > 0
      AND b.status IN ('Pending','Partially_Paid')
    ORDER BY s.outstanding_amount DESC;
END;
GO













/* ============================================================
   SAMPLE DATA (10+ records per table) - Microsoft SQL Server
   Schema must already exist (tables + constraints).
   ============================================================ */

SET NOCOUNT ON;

BEGIN TRAN;

/* ===========================
   1) ZONE (10)
   =========================== */
SET IDENTITY_INSERT dbo.ZONE ON;

INSERT INTO dbo.ZONE (zone_id, zone_name, region, office_address, office_phone) VALUES
(1,  N'Colombo South',   N'Western',    N'Galle Road, Colombo 03',      N'011-2000001'),
(2,  N'Colombo North',   N'Western',    N'Kotahena, Colombo 13',        N'011-2000002'),
(3,  N'Gampaha',         N'Western',    N'Gampaha Town',                N'033-2000003'),
(4,  N'Kalutara',        N'Western',    N'Kalutara South',              N'034-2000004'),
(5,  N'Kandy',           N'Central',    N'Peradeniya Rd, Kandy',        N'081-2000005'),
(6,  N'Galle',           N'Southern',   N'Galle Fort Area',             N'091-2000006'),
(7,  N'Matara',          N'Southern',   N'Matara Town',                 N'041-2000007'),
(8,  N'Kurunegala',      N'North Western', N'Kurunegala Town',          N'037-2000008'),
(9,  N'Jaffna',          N'Northern',   N'Jaffna City',                 N'021-2000009'),
(10, N'Batticaloa',      N'Eastern',    N'Batticaloa Town',             N'065-2000010');

SET IDENTITY_INSERT dbo.ZONE OFF;


/* ===========================
   2) STAFF (50) + Subtypes (10 each)
   Staff.status CHECK: Active/OnLeave/Resigned
   =========================== */
SET IDENTITY_INSERT dbo.STAFF ON;

INSERT INTO dbo.STAFF (staff_id, employee_no, full_name, phone, email, joined_date, status) VALUES
-- 1..10 Admin staff
(1,  N'EMP-ADM-001', N'Nimal Perera',     N'0771000001', N'nimal.perera@utility.gov.lk',   '2020-01-10', N'Active'),
(2,  N'EMP-ADM-002', N'Shashika Silva',   N'0771000002', N'shashika.silva@utility.gov.lk', '2021-02-14', N'Active'),
(3,  N'EMP-ADM-003', N'Ruwan Jayasinghe', N'0771000003', N'ruwan.j@utility.gov.lk',        '2022-03-18', N'Active'),
(4,  N'EMP-ADM-004', N'Kasun Fernando',   N'0771000004', N'kasun.f@utility.gov.lk',        '2019-07-01', N'OnLeave'),
(5,  N'EMP-ADM-005', N'Chamari De Silva', N'0771000005', N'chamari.ds@utility.gov.lk',     '2023-01-05', N'Active'),
(6,  N'EMP-ADM-006', N'Indika Weerasinghe',N'0771000006',N'indika.w@utility.gov.lk',       '2018-11-22', N'Active'),
(7,  N'EMP-ADM-007', N'Dilani Kumari',    N'0771000007', N'dilani.k@utility.gov.lk',       '2021-09-09', N'Active'),
(8,  N'EMP-ADM-008', N'Mahesh Priyanka',  N'0771000008', N'mahesh.p@utility.gov.lk',       '2020-05-30', N'Active'),
(9,  N'EMP-ADM-009', N'Sanduni Peiris',   N'0771000009', N'sanduni.p@utility.gov.lk',      '2022-10-12', N'Active'),
(10, N'EMP-ADM-010', N'Gihan Senanayake', N'0771000010', N'gihan.s@utility.gov.lk',         '2017-12-01', N'Resigned'),

-- 11..20 Meter Readers
(11, N'EMP-MR-011', N'Pradeep Karunaratne', N'0771000011', N'pradeep.k@utility.gov.lk', '2020-04-15', N'Active'),
(12, N'EMP-MR-012', N'Isuru Bandara',       N'0771000012', N'isuru.b@utility.gov.lk',   '2021-06-20', N'Active'),
(13, N'EMP-MR-013', N'Harsha Wijesinghe',   N'0771000013', N'harsha.w@utility.gov.lk',  '2019-08-10', N'Active'),
(14, N'EMP-MR-014', N'Rashmi Abeysekara',   N'0771000014', N'rashmi.a@utility.gov.lk',  '2022-01-17', N'Active'),
(15, N'EMP-MR-015', N'Thushara Pathirana',  N'0771000015', N'thushara.p@utility.gov.lk','2018-09-25', N'Active'),
(16, N'EMP-MR-016', N'Lakshan Niroshan',    N'0771000016', N'lakshan.n@utility.gov.lk', '2023-02-02', N'Active'),
(17, N'EMP-MR-017', N'Nilusha Hettiarachchi',N'0771000017',N'nilusha.h@utility.gov.lk', '2020-12-12', N'OnLeave'),
(18, N'EMP-MR-018', N'Chathura Madushan',   N'0771000018', N'chathura.m@utility.gov.lk','2021-11-11', N'Active'),
(19, N'EMP-MR-019', N'Priyanga Rathnayake', N'0771000019', N'priyanga.r@utility.gov.lk','2017-03-03', N'Active'),
(20, N'EMP-MR-020', N'Ashan Dias',          N'0771000020', N'ashan.d@utility.gov.lk',   '2016-05-05', N'Active'),

-- 21..30 Field Officers
(21, N'EMP-FO-021', N'Sameera Fernando', N'0771000021', N'sameera.f@utility.gov.lk', '2018-04-01', N'Active'),
(22, N'EMP-FO-022', N'Gayan Peris',      N'0771000022', N'gayan.p@utility.gov.lk',   '2019-05-02', N'Active'),
(23, N'EMP-FO-023', N'Janaka Rathnaweera',N'0771000023',N'janaka.r@utility.gov.lk',  '2020-06-03', N'Active'),
(24, N'EMP-FO-024', N'Chamara Dissanayake',N'0771000024',N'chamara.d@utility.gov.lk','2021-07-04', N'Active'),
(25, N'EMP-FO-025', N'Kasuni Jayawardena', N'0771000025', N'kasuni.j@utility.gov.lk','2022-08-05', N'Active'),
(26, N'EMP-FO-026', N'Imesh Gamage',     N'0771000026', N'imesh.g@utility.gov.lk',   '2023-09-06', N'Active'),
(27, N'EMP-FO-027', N'Tissera Gunasekara',N'0771000027', N'tissera.g@utility.gov.lk','2017-02-14', N'OnLeave'),
(28, N'EMP-FO-028', N'Minali Fernando',  N'0771000028', N'minali.f@utility.gov.lk',  '2016-12-12', N'Active'),
(29, N'EMP-FO-029', N'Chinthaka Silva',  N'0771000029', N'chinthaka.s@utility.gov.lk','2015-10-10',N'Active'),
(30, N'EMP-FO-030', N'Sujeewa Perera',   N'0771000030', N'sujeewa.p@utility.gov.lk', '2014-09-09', N'Active'),

-- 31..40 Cashiers
(31, N'EMP-CS-031', N'Ravindu Silva',    N'0771000031', N'ravindu.s@utility.gov.lk', '2020-01-01', N'Active'),
(32, N'EMP-CS-032', N'Nisala Perera',    N'0771000032', N'nisala.p@utility.gov.lk',  '2021-01-02', N'Active'),
(33, N'EMP-CS-033', N'Shalini Fernando', N'0771000033', N'shalini.f@utility.gov.lk', '2022-01-03', N'Active'),
(34, N'EMP-CS-034', N'Dinesh Wickrama',  N'0771000034', N'dinesh.w@utility.gov.lk',  '2023-01-04', N'Active'),
(35, N'EMP-CS-035', N'Ruwani Jayasooriya',N'0771000035',N'ruwani.j@utility.gov.lk',  '2019-03-03', N'Active'),
(36, N'EMP-CS-036', N'Kavindu Maduranga',N'0771000036', N'kavindu.m@utility.gov.lk', '2018-04-04', N'OnLeave'),
(37, N'EMP-CS-037', N'Hasini Peiris',    N'0771000037', N'hasini.p@utility.gov.lk',  '2017-05-05', N'Active'),
(38, N'EMP-CS-038', N'Chathumini Silva', N'0771000038', N'chathumini.s@utility.gov.lk','2016-06-06',N'Active'),
(39, N'EMP-CS-039', N'Malith Perera',    N'0771000039', N'malith.p@utility.gov.lk',  '2015-07-07', N'Active'),
(40, N'EMP-CS-040', N'Thanuja Fernando', N'0771000040', N'thanuja.f@utility.gov.lk', '2014-08-08', N'Resigned'),

-- 41..50 Managers
(41, N'EMP-MG-041', N'Ranjith Wijeratne', N'0771000041', N'ranjith.w@utility.gov.lk', '2012-02-02', N'Active'),
(42, N'EMP-MG-042', N'Nalini Perera',     N'0771000042', N'nalini.p@utility.gov.lk',   '2013-03-03', N'Active'),
(43, N'EMP-MG-043', N'Ajith Fernando',    N'0771000043', N'ajith.f@utility.gov.lk',    '2011-01-01', N'Active'),
(44, N'EMP-MG-044', N'Supun Silva',       N'0771000044', N'supun.s@utility.gov.lk',    '2014-04-04', N'Active'),
(45, N'EMP-MG-045', N'Chandani Jayasena', N'0771000045', N'chandani.j@utility.gov.lk', '2015-05-05', N'Active'),
(46, N'EMP-MG-046', N'Kanishka Perera',   N'0771000046', N'kanishka.p@utility.gov.lk', '2016-06-06', N'Active'),
(47, N'EMP-MG-047', N'Yasith Gunawardena',N'0771000047', N'yasith.g@utility.gov.lk',   '2017-07-07', N'Active'),
(48, N'EMP-MG-048', N'Dayani Fernando',   N'0771000048', N'dayani.f@utility.gov.lk',   '2018-08-08', N'OnLeave'),
(49, N'EMP-MG-049', N'Lasitha Silva',     N'0771000049', N'lasitha.s@utility.gov.lk',  '2019-09-09', N'Active'),
(50, N'EMP-MG-050', N'Tharanga Perera',   N'0771000050', N'tharanga.p@utility.gov.lk', '2020-10-10', N'Active');

SET IDENTITY_INSERT dbo.STAFF OFF;

-- Subtypes (10 each)
INSERT INTO dbo.ADMINISTRATIVE_STAFF (staff_id, department, can_manage_tariffs, can_register_connections, shift_type) VALUES
(1,N'CustomerService',1,1,N'Day'),(2,N'Tariff',1,0,N'Day'),(3,N'Complaints',0,1,N'Rotational'),
(4,N'CustomerService',0,1,N'Night'),(5,N'BillingSupport',0,1,N'Day'),
(6,N'Tariff',1,0,N'Day'),(7,N'Complaints',0,1,N'Rotational'),
(8,N'CustomerService',0,1,N'Day'),(9,N'BillingSupport',0,1,N'Rotational'),(10,N'Tariff',1,0,N'Day');

INSERT INTO dbo.METER_READER (staff_id, device_id, route_code) VALUES
(11,N'MR-DEV-11',N'CLB-S-01'),(12,N'MR-DEV-12',N'CLB-N-01'),(13,N'MR-DEV-13',N'GAM-01'),
(14,N'MR-DEV-14',N'KLT-01'),(15,N'MR-DEV-15',N'KDY-01'),
(16,N'MR-DEV-16',N'GAL-01'),(17,N'MR-DEV-17',N'MTR-01'),
(18,N'MR-DEV-18',N'KUR-01'),(19,N'MR-DEV-19',N'JAF-01'),(20,N'MR-DEV-20',N'BAT-01');

INSERT INTO dbo.FIELD_OFFICER (staff_id, route_code, certification_level, shift_type, vehicle_no) VALUES
(21,N'CLB-S-FO',N'Advanced',N'Day',N'WP-FO-1001'),
(22,N'CLB-N-FO',N'Basic',N'Day',N'WP-FO-1002'),
(23,N'GAM-FO',  N'Basic',N'Rotational',N'WP-FO-1003'),
(24,N'KLT-FO',  N'Advanced',N'Night',N'WP-FO-1004'),
(25,N'KDY-FO',  N'Safety-Certified',N'Day',N'CP-FO-2001'),
(26,N'GAL-FO',  N'Basic',N'Day',N'SP-FO-3001'),
(27,N'MTR-FO',  N'Advanced',N'Rotational',N'SP-FO-3002'),
(28,N'KUR-FO',  N'Basic',N'Day',N'NW-FO-4001'),
(29,N'JAF-FO',  N'Safety-Certified',N'Day',N'NP-FO-5001'),
(30,N'BAT-FO',  N'Basic',N'Day',N'EP-FO-6001');

INSERT INTO dbo.CASHIER (staff_id, counter_no, cash_drawer_id, shift_type) VALUES
(31,N'C-01',N'DR-01',N'Day'),(32,N'C-02',N'DR-02',N'Day'),(33,N'C-03',N'DR-03',N'Rotational'),
(34,N'C-04',N'DR-04',N'Day'),(35,N'C-05',N'DR-05',N'Day'),
(36,N'C-06',N'DR-06',N'Night'),(37,N'C-07',N'DR-07',N'Day'),
(38,N'C-08',N'DR-08',N'Rotational'),(39,N'C-09',N'DR-09',N'Day'),(40,N'C-10',N'DR-10',N'Day');

INSERT INTO dbo.MANAGER (staff_id, management_level, approval_limit_amount, report_access_level) VALUES
(41,N'Regional', 5000000.00, N'Region'),
(42,N'Area',     2000000.00, N'Zone'),
(43,N'HQ',      25000000.00, N'National'),
(44,N'Regional', 7000000.00, N'Region'),
(45,N'Area',     3000000.00, N'Zone'),
(46,N'Area',     3000000.00, N'Zone'),
(47,N'Regional', 8000000.00, N'Region'),
(48,N'HQ',      20000000.00, N'National'),
(49,N'Area',     1500000.00, N'Zone'),
(50,N'Regional', 9000000.00, N'Region');


/* ===========================
   3) CUSTOMER (>=10) + identity fields
   =========================== */
SET IDENTITY_INSERT dbo.CUSTOMER ON;

INSERT INTO dbo.CUSTOMER
(customer_id, zone_id, full_name, identity_type, identity_ref, phone, email, address_line1, address_line2, city, postal_code, registration_date, status)
VALUES
(1, 1, N'Lakmal Perera',      N'NIC',      N'901234567V', N'0772000001', N'lakmal@gmail.com',   N'12', N'Colombo 03', N'Colombo', N'00300', '2024-01-05', N'Active'),
(2, 1, N'Sewwandi Silva',     N'NIC',      N'925678901V', N'0772000002', N'sewwandi@gmail.com', N'55', N'Kirulapone', N'Colombo', N'00500', '2024-02-10', N'Active'),
(3, 3, N'Royal Traders (Pvt) Ltd', N'BRN', N'PV12345',    N'0115550003', N'accounts@royal.lk',   N'200',N'Yakkala',   N'Gampaha', N'11000', '2023-08-01', N'Active'),
(4, 5, N'Kandy Central College', N'Other', N'SCH-7788',   N'0815550004', N'office@kcc.edu.lk',  N'1',  N'Peradeniya Rd', N'Kandy', N'20000','2022-05-15', N'Active'),
(5, 6, N'Galle Temple Trust',  N'Other',   N'TMP-1001',   N'0915550005', NULL,                  N'9',  N'Fort',      N'Galle',  N'80000', '2021-11-20', N'Active'),
(6, 2, N'Hasitha Fernando',    N'Passport',N'N1234567',   N'0772000006', N'hasitha@gmail.com',  N'89', N'Kotahena',   N'Colombo', N'01300', '2024-03-01', N'Active'),
(7, 4, N'Shanaka Jayasinghe',  N'NIC',     N'881234567V', N'0772000007', NULL,                  N'10', N'Panadura',   N'Kalutara', N'12500', '2020-06-06', N'Active'),
(8, 7, N'Nilmini Abeysekara',  N'NIC',     N'905551234V', N'0772000008', N'nilmini@gmail.com',  N'77', N'Nupe',       N'Matara', N'81000', '2024-04-12', N'Active'),
(9, 8, N'Kurunegala Hardware', N'BRN',     N'BRN-778899', N'0375550009', N'kurunegala.hw@gmail.com', N'19', N'Town', N'Kurunegala', N'60000', '2023-10-10', N'Active'),
(10,9, N'Jaffna Foods',        N'BRN',     N'BRN-110022', N'0215550010', N'finance@jaffnafoods.lk', N'5', N'Jaffna', N'Jaffna', N'40000', '2022-09-09', N'Active'),
(11,10,N'Batticaloa Clinic',   N'Other',   N'CLN-2020',   N'0655550011', NULL,                  N'21', N'BT Town',    N'Batticaloa', N'30000', '2021-01-01', N'Active'),
(12,1, N'Theekshana Perera',   N'NIC',     N'990011223V', N'0772000012', NULL,                  N'45', N'Borella',    N'Colombo', N'00800', '2024-05-20', N'Active');

SET IDENTITY_INSERT dbo.CUSTOMER OFF;


/* ===========================
   4) TARIFF_CATEGORY (10)
   utility_type CHECK: Electricity/Water/Gas
   =========================== */
SET IDENTITY_INSERT dbo.TARIFF_CATEGORY ON;

INSERT INTO dbo.TARIFF_CATEGORY
(tariff_category_id, utility_type, code, name, description, is_subsidized)
VALUES
(1, N'Electricity', N'DOM',   N'Domestic - Standard',     N'Household domestic tariff', 1),
(2, N'Electricity', N'DOM-LOW',N'Domestic - Low Use',    N'Low consumption category',  1),
(3, N'Electricity', N'COM',   N'Commercial - Small',     N'Small commercial users',    0),
(4, N'Electricity', N'IND',   N'Industrial - Medium',    N'Medium industrial users',  0),
(5, N'Electricity', N'GOV',   N'Government',             N'Gov institutions',          0),
(6, N'Water',       N'W-DOM', N'Water Domestic',          N'Residential water supply', 1),
(7, N'Water',       N'W-COM', N'Water Commercial',        N'Commercial water supply',  0),
(8, N'Gas',         N'G-DOM', N'Gas Domestic',            N'Residential gas supply',   0),
(9, N'Gas',         N'G-COM', N'Gas Commercial',          N'Commercial gas supply',    0),
(10,N'Electricity', N'RENT',  N'Rental Premises',         N'Rental properties',        0);

SET IDENTITY_INSERT dbo.TARIFF_CATEGORY OFF;


 /* ===========================
    5) TARIFF_SLAB (>=10) Electricity DOM + Water DOM + Gas DOM
    =========================== */
SET IDENTITY_INSERT dbo.TARIFF_SLAB ON;

INSERT INTO dbo.TARIFF_SLAB
(slab_id, tariff_category_id, valid_from, valid_to, min_units, max_units, unit_price, fixed_charge)
VALUES
-- Electricity Domestic Standard (1)
(1, 1, '2025-01-01', NULL, 0,  60,  30.00,  400.00),
(2, 1, '2025-01-01', NULL, 60, 90,  45.00,  600.00),
(3, 1, '2025-01-01', NULL, 90, 120, 60.00, 1000.00),
(4, 1, '2025-01-01', NULL, 120, NULL, 75.00, 1500.00),

-- Electricity Domestic Low Use (2)
(5, 2, '2025-01-01', NULL, 0,  30,  20.00,  200.00),
(6, 2, '2025-01-01', NULL, 30, 60,  30.00,  300.00),

-- Water Domestic (6)
(7, 6, '2025-01-01', NULL, 0,  10,  60.00,  250.00),
(8, 6, '2025-01-01', NULL, 10, 20,  80.00,  350.00),
(9, 6, '2025-01-01', NULL, 20, NULL, 100.00, 500.00),

-- Gas Domestic (8)
(10,8, '2025-01-01', NULL, 0,  15,  90.00,  300.00),
(11,8, '2025-01-01', NULL, 15, NULL, 110.00, 450.00),

-- Electricity Commercial Small (3) (extra)
(12,3, '2025-01-01', NULL, 0,  100, 65.00, 2000.00),
(13,3, '2025-01-01', NULL, 100, NULL, 85.00, 3000.00);

SET IDENTITY_INSERT dbo.TARIFF_SLAB OFF;


 /* ===========================
    6) CONNECTION (>=10) + Landlord scenario (zone differs from customer)
    connection_status CHECK includes Active/Suspended/Closed/Pending/Temporary_Disconnected/Awaiting_Approval/Pending_Investigation
    =========================== */
SET IDENTITY_INSERT dbo._CONNECTION ON;

INSERT INTO dbo._CONNECTION
(connection_id, customer_id, zone_id, utility_type, service_address, tariff_category_id, connection_status, start_date, end_date)
VALUES
-- Landlord scenario: Customer 1 lives in Colombo (zone 1) but owns rental shop in Galle (zone 6)
(1,  1, 6, N'Electricity', N'No 10, Lighthouse St, Galle',     3,  N'Active', '2023-01-01', NULL),
(2,  1, 6, N'Water',       N'No 10, Lighthouse St, Galle',     7,  N'Active', '2023-01-01', NULL),

-- Colombo domestic
(3,  2, 1, N'Electricity', N'No 55, Kirulapone, Colombo 05',   1,  N'Active', '2024-02-15', NULL),
(4,  2, 1, N'Water',       N'No 55, Kirulapone, Colombo 05',   6,  N'Active', '2024-02-15', NULL),

-- Business in Gampaha
(5,  3, 3, N'Electricity', N'Royal Traders Warehouse, Yakkala',4,  N'Active', '2021-06-01', NULL),

-- School in Kandy
(6,  4, 5, N'Electricity', N'KCC Main Building, Kandy',        5,  N'Active', '2019-01-01', NULL),
(7,  4, 5, N'Water',       N'KCC Main Building, Kandy',        6,  N'Active', '2019-01-01', NULL),

-- Temple in Galle (electricity)
(8,  5, 6, N'Electricity', N'Galle Temple, Fort',              5,  N'Active', '2018-03-01', NULL),

-- Kotahena (Colombo North)
(9,  6, 2, N'Electricity', N'No 89, Kotahena, Colombo 13',     1,  N'Active', '2022-07-07', NULL),

-- Kalutara (Panadura)
(10, 7, 4, N'Electricity', N'No 10, Panadura, Kalutara',       2,  N'Active', '2020-06-06', NULL),

-- Matara domestic
(11, 8, 7, N'Electricity', N'No 77, Nupe, Matara',             1,  N'Active', '2024-04-15', NULL),
(12, 8, 7, N'Water',       N'No 77, Nupe, Matara',             6,  N'Active', '2024-04-15', NULL),

-- Kurunegala hardware
(13, 9, 8, N'Electricity', N'Kurunegala Hardware, Town',       3,  N'Active', '2023-10-15', NULL),

-- Jaffna foods
(14, 10, 9, N'Electricity', N'Jaffna Foods Factory, Jaffna',   4,  N'Active', '2022-09-15', NULL),

-- Batticaloa clinic
(15, 11, 10, N'Electricity', N'Batticaloa Clinic, BT Town',    5,  N'Active', '2021-01-15', NULL);

SET IDENTITY_INSERT dbo._CONNECTION OFF;


 /* ===========================
    7) METER (>=10) including replacements
    - Must obey filtered index: only 1 Active per connection
    - meter_role in (Standard, Net_Meter, Generation_Only)
    - status in (Active, Removed, Faulty)
    =========================== */
SET IDENTITY_INSERT dbo.METER ON;

INSERT INTO dbo.METER
(meter_id, connection_id, meter_serial_no, meter_type, meter_role, installed_from, removed_at, status, is_smart_meter)
VALUES
-- Connection 1: old removed + active net meter (solar export)
(1,  1, N'CEB-EL-000001', N'Postpaid', N'Standard', '2023-01-01', '2024-12-31', N'Removed', 0),
(2,  1, N'CEB-EL-000002', N'Postpaid', N'Net_Meter','2025-01-01', NULL,         N'Active',  1),

-- Connection 2 (Water)
(3,  2, N'NWS-WS-000003', N'Postpaid', N'Standard', '2023-01-01', NULL,         N'Active',  0),

-- Connection 3: meter replaced
(4,  3, N'CEB-EL-000004', N'Postpaid', N'Standard', '2024-02-15', '2025-06-30', N'Faulty',  0),
(5,  3, N'CEB-EL-000005', N'Postpaid', N'Net_Meter','2025-07-01', NULL,         N'Active',  1),

-- Connection 4 (Water)
(6,  4, N'NWS-WS-000006', N'Postpaid', N'Standard', '2024-02-15', NULL,         N'Active',  0),

-- Connection 5 (Industrial)
(7,  5, N'CEB-EL-000007', N'Postpaid', N'Standard', '2021-06-01', NULL,         N'Active',  1),

-- Connection 6 (School)
(8,  6, N'CEB-EL-000008', N'Postpaid', N'Standard', '2019-01-01', '2023-12-31', N'Removed', 0),
(9,  6, N'CEB-EL-000009', N'Postpaid', N'Net_Meter','2024-01-01', NULL,         N'Active',  1),

-- Connection 7 (Water)
(10, 7, N'NWS-WS-000010', N'Postpaid', N'Standard', '2019-01-01', NULL,         N'Active',  0),

-- Connection 8 (Temple)
(11, 8, N'CEB-EL-000011', N'Postpaid', N'Net_Meter','2018-03-01', NULL,         N'Active',  0),

-- Connection 9 (Kotahena)
(12, 9, N'CEB-EL-000012', N'Postpaid', N'Standard', '2022-07-07', NULL,         N'Active',  1),

-- Connection 10 (Kalutara low use)
(13,10, N'CEB-EL-000013', N'Postpaid', N'Standard', '2020-06-06', NULL,         N'Active',  0),

-- Connection 11 (Matara)
(14,11, N'CEB-EL-000014', N'Postpaid', N'Net_Meter','2024-04-15', NULL,         N'Active',  1),

-- Connection 12 (Matara water)
(15,12, N'NWS-WS-000015', N'Postpaid', N'Standard', '2024-04-15', NULL,         N'Active',  0),

-- Connection 13 (Kurunegala)
(16,13, N'CEB-EL-000016', N'Postpaid', N'Standard', '2023-10-15', NULL,         N'Active',  1),

-- Connection 14 (Jaffna)
(17,14, N'CEB-EL-000017', N'Postpaid', N'Standard', '2022-09-15', NULL,         N'Active',  1),

-- Connection 15 (Batticaloa)
(18,15, N'CEB-EL-000018', N'Postpaid', N'Standard', '2021-01-15', NULL,         N'Active',  0);

SET IDENTITY_INSERT dbo.METER OFF;


 /* ===========================
    8) SOLAR_INSTALLATION (10)
    Unique per connection_id (UQ_SOLAR_installation_per_connection)
    =========================== */
SET IDENTITY_INSERT dbo.SOLAR_INSTALLATION ON;

INSERT INTO dbo.SOLAR_INSTALLATION
(solar_id, connection_id, installed_capacity_kw, scheme_type, approval_ref, agreement_start_date, agreement_end_date, status)
VALUES
(1,  1,  5.00, N'Net_Plus',      N'SOL-APP-0001', '2025-01-01', '2044-12-31', N'Active'),
(2,  3,  2.00, N'Net_Metering',  N'SOL-APP-0002', '2025-07-01', '2045-06-30', N'Active'),
(3,  6, 10.00, N'Net_Accounting',N'SOL-APP-0003', '2024-01-01', '2043-12-31', N'Active'),
(4,  8,  3.00, N'Net_Metering',  N'SOL-APP-0004', '2023-01-01', '2042-12-31', N'Active'),
(5,  9,  2.50, N'Net_Accounting',N'SOL-APP-0005', '2024-06-01', '2044-05-31', N'Active'),
(6, 10,  1.50, N'Net_Metering',  N'SOL-APP-0006', '2024-02-01', '2044-01-31', N'Active'),
(7, 11,  4.00, N'Net_Plus',      N'SOL-APP-0007', '2025-01-15', '2044-12-31', N'Active'),
(8, 13,  6.00, N'Net_Accounting',N'SOL-APP-0008', '2025-03-01', '2045-02-28', N'Active'),
(9, 14,  8.00, N'Net_Plus',      N'SOL-APP-0009', '2024-09-01', '2044-08-31', N'Active'),
(10,15,  3.50, N'Net_Metering',  N'SOL-APP-0010', '2024-12-01', '2044-11-30', N'Active');

SET IDENTITY_INSERT dbo.SOLAR_INSTALLATION OFF;


 /* ===========================
    9) METER_READING (>=10) - create meaningful readings for active meters
    reading_source CHECK: Manual/Mobile_App/Smart_Meter/Estimated/Adjusted
    captured_by_staff_id must exist
    =========================== */
SET IDENTITY_INSERT dbo.METER_READING ON;

-- For each active electricity meter, provide readings across months (import/export for net meters)
INSERT INTO dbo.METER_READING
(reading_id, meter_id, reading_date, import_reading, export_reading, reading_source, captured_by_staff_id)
VALUES
-- Meter 2 (Conn1 Net Meter): Oct/Nov/Dec
(1,  2, '2025-09-30', 1200.000,  300.000, N'Smart_Meter', 11),
(2,  2, '2025-10-31', 1350.000,  360.000, N'Smart_Meter', 11),
(3,  2, '2025-11-30', 1505.000,  420.000, N'Smart_Meter', 12),

-- Meter 3 (Water Conn2): Oct/Nov
(4,  3, '2025-09-30',  80.000, NULL, N'Manual', 13),
(5,  3, '2025-10-31',  92.000, NULL, N'Manual', 13),

-- Meter 5 (Conn3 Net Meter): Oct/Nov
(6,  5, '2025-09-30',  500.000,  20.000, N'Smart_Meter', 14),
(7,  5, '2025-10-31',  620.000,  38.000, N'Smart_Meter', 14),

-- Meter 6 (Water Conn4)
(8,  6, '2025-09-30',  40.000, NULL, N'Mobile_App', 15),
(9,  6, '2025-10-31',  52.000, NULL, N'Mobile_App', 15),

-- Meter 7 (Conn5 Industrial)
(10, 7, '2025-09-30', 10000.000, NULL, N'Smart_Meter', 16),
(11, 7, '2025-10-31', 10680.000, NULL, N'Smart_Meter', 16),

-- Meter 9 (Conn6 Net Meter)
(12, 9, '2025-09-30',  9000.000,  200.000, N'Smart_Meter', 17),
(13, 9, '2025-10-31',  9400.000,  260.000, N'Smart_Meter', 17),

-- Meter 10 (Water Conn7)
(14,10, '2025-09-30',  300.000, NULL, N'Manual', 18),
(15,10, '2025-10-31',  315.000, NULL, N'Manual', 18),

-- Meter 11 (Conn8 Net Meter)
(16,11, '2025-09-30',  2200.000,  90.000, N'Mobile_App', 19),
(17,11, '2025-10-31',  2365.000, 120.000, N'Mobile_App', 19),

-- Meter 12 (Conn9 Standard)
(18,12, '2025-09-30',  1500.000, NULL, N'Smart_Meter', 20),
(19,12, '2025-10-31',  1615.000, NULL, N'Smart_Meter', 20),

-- Meter 13 (Conn10 Low use)
(20,13, '2025-09-30',   200.000, NULL, N'Manual', 11),
(21,13, '2025-10-31',   240.000, NULL, N'Manual', 11),

-- Meter 14 (Conn11 Net Meter)
(22,14, '2025-09-30',   300.000,  10.000, N'Smart_Meter', 12),
(23,14, '2025-10-31',   410.000,  22.000, N'Smart_Meter', 12),

-- Meter 15 (Conn12 Water)
(24,15, '2025-09-30',    20.000, NULL, N'Manual', 13),
(25,15, '2025-10-31',    28.000, NULL, N'Manual', 13),

-- Meter 16 (Conn13 Standard)
(26,16, '2025-09-30',  700.000, NULL, N'Smart_Meter', 14),
(27,16, '2025-10-31',  860.000, NULL, N'Smart_Meter', 14),

-- Meter 17 (Conn14 Standard)
(28,17, '2025-09-30', 5000.000, NULL, N'Smart_Meter', 15),
(29,17, '2025-10-31', 5450.000, NULL, N'Smart_Meter', 15),

-- Meter 18 (Conn15 Standard)
(30,18, '2025-09-30',  900.000, NULL, N'Mobile_App', 16),
(31,18, '2025-10-31',  980.000, NULL, N'Mobile_App', 16);

SET IDENTITY_INSERT dbo.METER_READING OFF;


 /* ===========================
    10) SUBSIDY_SCHEME (10)
    =========================== */
SET IDENTITY_INSERT dbo.SUBSIDY_SCHEME ON;

INSERT INTO dbo.SUBSIDY_SCHEME
(subsidy_id, name, discount_type, discount_value, valid_from, valid_to, description)
VALUES
(1, N'Domestic Relief 2025 A', N'Percentage', 5.00,  '2025-01-01', NULL, N'5% relief for eligible domestic users'),
(2, N'Senior Citizen Support', N'Percentage', 8.00,  '2025-01-01', NULL, N'8% for senior citizens'),
(3, N'Low Income Grant',       N'Fixed',     500.00,'2025-01-01', NULL, N'Fixed Rs.500 subsidy'),
(4, N'Medical Facility Support',N'Percentage',10.00,'2025-01-01', NULL, N'10% for medical facilities'),
(5, N'Education Support',      N'Percentage',12.00,'2025-01-01', NULL, N'12% for schools'),
(6, N'Religious Place Support',N'Fixed',     300.00,'2025-01-01', NULL, N'Fixed Rs.300 for places of worship'),
(7, N'Drought Water Relief',   N'Fixed',     200.00,'2025-06-01', '2025-12-31', N'Temporary relief for water'),
(8, N'Industry Energy Efficiency',N'Percentage',3.00,'2025-01-01', NULL, N'3% for approved industry'),
(9, N'Northern Province Support',N'Percentage',6.00,'2025-01-01', NULL, N'6% regional support'),
(10,N'Elderly Water Support',  N'Fixed',     150.00,'2025-01-01', NULL, N'Fixed Rs.150 water support');

SET IDENTITY_INSERT dbo.SUBSIDY_SCHEME OFF;


 /* ===========================
    11) CUSTOMER_SUBSIDY (10)
    status must be in ('Active','Expired','Cancelled','Pending','Awaiting_Approval')
    =========================== */
SET IDENTITY_INSERT dbo.CUSTOMER_SUBSIDY ON;

INSERT INTO dbo.CUSTOMER_SUBSIDY
(customer_subsidy_id, customer_id, subsidy_id, approved_by_staff_id, approved_date, status)
VALUES
(1,  1, 1, 2, '2025-01-10', N'Active'),
(2,  2, 2, 1, '2025-02-01', N'Active'),
(3,  4, 5, 6, '2025-01-20', N'Active'),
(4,  5, 6, 7, '2025-03-05', N'Active'),
(5,  7, 3, 8, '2025-04-01', N'Active'),
(6,  8, 1, 9, '2025-02-15', N'Active'),
(7,  10,9, 41,'2025-01-25', N'Active'),
(8,  11,4, 42,'2025-01-15', N'Active'),
(9,  12,1, 3, '2025-05-25', N'Pending'),
(10, 3, 8, 43,'2025-02-22', N'Awaiting_Approval');

SET IDENTITY_INSERT dbo.CUSTOMER_SUBSIDY OFF;


 /* ===========================
    12) TAX_CONFIG (10)
    status Active/Inactive
    =========================== */
SET IDENTITY_INSERT dbo.TAX_CONFIG ON;

INSERT INTO dbo.TAX_CONFIG
(tax_id, tax_name, rate_percent, effective_from, effective_to, status, created_by_staff_id, created_at)
VALUES
(1, N'VAT',     18.000, '2025-01-01', NULL,        N'Active',   2, '2025-01-01T09:00:00'),
(2, N'SSCL',     2.500, '2025-01-01', NULL,        N'Active',   2, '2025-01-01T09:05:00'),
(3, N'NBT',      0.000, '2020-01-01', '2024-12-31',N'Inactive', 6, '2024-12-31T18:00:00'),
(4, N'Env_Levy', 0.500, '2025-06-01', NULL,        N'Active',   6, '2025-06-01T09:00:00'),
(5, N'Local_Tax_A',1.000,'2025-01-01','2025-03-31',N'Inactive', 1, '2025-04-01T08:00:00'),
(6, N'Local_Tax_B',1.000,'2025-04-01','2025-05-31',N'Inactive', 1, '2025-06-01T08:00:00'),
(7, N'Local_Tax_C',1.000,'2025-06-01','2025-07-31',N'Inactive', 1, '2025-08-01T08:00:00'),
(8, N'Local_Tax_D',1.000,'2025-08-01','2025-09-30',N'Inactive', 1, '2025-10-01T08:00:00'),
(9, N'Local_Tax_E',1.000,'2025-10-01','2025-11-30',N'Inactive', 1, '2025-12-01T08:00:00'),
(10,N'Local_Tax_F',1.000,'2025-12-01','2025-12-31',N'Inactive', 1, '2026-01-01T08:00:00');

SET IDENTITY_INSERT dbo.TAX_CONFIG OFF;


 /* ===========================
    13) BILL (10)
    - Use Oct 2025 bills for 10 connections
    - status must be Pending/Partially_Paid/Paid/Cancelled
    =========================== */
SET IDENTITY_INSERT dbo.BILL ON;

INSERT INTO dbo.BILL
(bill_id, connection_id, meter_id, billing_period_start, billing_period_end, bill_date, due_date,
 total_import_units, total_export_units,
 energy_charge_amount, fixed_charge_amount, subsidy_amount, solar_export_credit, tax_total_amount, net_amount,
 status, generated_by_staff_id)
VALUES
(1,  1,  2, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 150.000, 60.000,  6000.00, 2000.00,  0.00, 1200.00,  0.00, 6800.00, N'Pending',        5),
(2,  2,  3, '2025-10-01','2025-10-31','2025-11-01','2025-11-14',  12.000, NULL,    960.00,  350.00,  0.00,    0.00,  0.00, 1310.00, N'Paid',           5),
(3,  3,  5, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 120.000, 18.000,  5400.00, 1500.00,  300.00,  500.00,  0.00, 6100.00, N'Partially_Paid', 6),
(4,  4,  6, '2025-10-01','2025-10-31','2025-11-01','2025-11-14',  12.000, NULL,    720.00,  250.00,  150.00,    0.00,  0.00,  820.00, N'Paid',           6),
(5,  5,  7, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 680.000, NULL,  52000.00, 3000.00,  0.00,    0.00,  0.00, 55000.00, N'Pending',        2),
(6,  6,  9, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 400.000, 60.000, 24000.00, 3000.00,  3500.00, 1500.00, 0.00, 25000.00, N'Pending',        3),
(7,  7, 10, '2025-10-01','2025-10-31','2025-11-01','2025-11-14',  15.000, NULL,   1050.00,  350.00,  0.00,    0.00,  0.00, 1400.00, N'Paid',           3),
(8,  8, 11, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 165.000, 30.000,  7000.00, 2000.00,  300.00,  700.00, 0.00, 8000.00, N'Partially_Paid', 1),
(9,  9, 12, '2025-10-01','2025-10-31','2025-11-01','2025-11-14', 115.000, NULL,   6000.00, 1500.00,  0.00,    0.00,  0.00, 7500.00, N'Pending',        1),
(10,10, 13, '2025-10-01','2025-10-31','2025-11-01','2025-11-14',  40.000, NULL,   1200.00,  300.00,  500.00,    0.00,  0.00, 1000.00, N'Paid',           2);

SET IDENTITY_INSERT dbo.BILL OFF;


 /* ===========================
    14) BILL_DETAIL (>=10) – 2 rows per bill => 20
    =========================== */
SET IDENTITY_INSERT dbo.BILL_DETAIL ON;

INSERT INTO dbo.BILL_DETAIL (bill_detail_id, bill_id, slab_id, units_in_slab, amount) VALUES
-- Bill 1 (Commercial small slabs used as example: slab 12/13)
(1, 1, 12, 100.000, 6500.00),
(2, 1, 13,  50.000, 4250.00),

-- Bill 2 (Water domestic slab 7/8)
(3, 2, 7, 10.000, 600.00),
(4, 2, 8,  2.000, 160.00),

-- Bill 3 (Domestic standard 1/2)
(5, 3, 1, 60.000, 1800.00),
(6, 3, 2, 60.000, 2700.00),

-- Bill 4 (Water domestic 7/8)
(7, 4, 7, 10.000, 600.00),
(8, 4, 8,  2.000, 160.00),

-- Bill 5 (Industrial category is simplified using commercial slabs 12/13)
(9,  5, 12, 100.000, 6500.00),
(10, 5, 13, 580.000, 49300.00),

-- Bill 6 (Gov usage: use domestic slabs for illustration)
(11, 6, 2, 90.000, 4050.00),
(12, 6, 4, 310.000, 23250.00),

-- Bill 7 (Water domestic for school)
(13, 7, 7, 10.000, 600.00),
(14, 7, 8,  5.000, 400.00),

-- Bill 8 (Gov temple electricity: domestic slabs)
(15, 8, 1, 60.000, 1800.00),
(16, 8, 4, 105.000, 7875.00),

-- Bill 9 (Domestic standard)
(17, 9, 1, 60.000, 1800.00),
(18, 9, 3, 55.000, 3300.00),

-- Bill 10 (Low use)
(19,10, 5, 30.000, 600.00),
(20,10, 6, 10.000, 300.00);

SET IDENTITY_INSERT dbo.BILL_DETAIL OFF;


 /* ===========================
    15) BILL_TAX (>=10) – 2 taxes per bill => 20
    We use VAT(1) + SSCL(2) to keep it meaningful
    =========================== */
SET IDENTITY_INSERT dbo.BILL_TAX ON;

INSERT INTO dbo.BILL_TAX
(bill_tax_id, bill_id, tax_id, rate_percent_applied, taxable_base_amount, tax_amount)
VALUES
-- Bill 1
(1,  1, 1, 18.000, 6800.00, 1224.00),
(2,  1, 2,  2.500, 6800.00, 170.00),

-- Bill 2
(3,  2, 1, 18.000, 1310.00, 235.80),
(4,  2, 2,  2.500, 1310.00, 32.75),

-- Bill 3
(5,  3, 1, 18.000, 6100.00, 1098.00),
(6,  3, 2,  2.500, 6100.00, 152.50),

-- Bill 4
(7,  4, 1, 18.000,  820.00, 147.60),
(8,  4, 2,  2.500,  820.00, 20.50),

-- Bill 5
(9,  5, 1, 18.000, 55000.00, 9900.00),
(10, 5, 2,  2.500, 55000.00, 1375.00),

-- Bill 6
(11, 6, 1, 18.000, 25000.00, 4500.00),
(12, 6, 2,  2.500, 25000.00, 625.00),

-- Bill 7
(13, 7, 1, 18.000, 1400.00, 252.00),
(14, 7, 2,  2.500, 1400.00, 35.00),

-- Bill 8
(15, 8, 1, 18.000, 8000.00, 1440.00),
(16, 8, 2,  2.500, 8000.00, 200.00),

-- Bill 9
(17, 9, 1, 18.000, 7500.00, 1350.00),
(18, 9, 2,  2.500, 7500.00, 187.50),

-- Bill 10
(19,10, 1, 18.000, 1000.00, 180.00),
(20,10, 2,  2.500, 1000.00, 25.00);

SET IDENTITY_INSERT dbo.BILL_TAX OFF;

-- If you created the BILL_TAX trigger earlier, BILL.tax_total_amount and BILL.net_amount will auto-update.
-- If not, you can optionally update them here:
UPDATE b
SET tax_total_amount = t.tax_total,
    net_amount = ROUND((b.energy_charge_amount + b.fixed_charge_amount - b.subsidy_amount - b.solar_export_credit + t.tax_total), 2)
FROM dbo.BILL b
JOIN (
    SELECT bill_id, SUM(tax_amount) AS tax_total
    FROM dbo.BILL_TAX
    GROUP BY bill_id
) t ON t.bill_id = b.bill_id;


 /* ===========================
    16) PAYMENT (>=10)
    payment_method CHECK: Cash/Card/Online/Bank/QR
    Trigger (if enabled) updates bill status automatically.
    =========================== */
SET IDENTITY_INSERT dbo.PAYMENT ON;

INSERT INTO dbo.PAYMENT
(payment_id, bill_id, payment_date, payment_amount, payment_method, payment_channel, transaction_ref, recorded_by_staff_id)
VALUES
(1,  2, '2025-11-05T10:10:00', 1579.00, N'Card',   N'Branch', N'TXN-0001', 31),
(2,  4, '2025-11-06T11:20:00',  988.10, N'Cash',   N'Branch', N'TXN-0002', 32),
(3,  7, '2025-11-07T09:15:00', 1687.00, N'Online', N'App',    N'TXN-0003', 33),
(4, 10, '2025-11-08T15:45:00', 1205.00, N'QR',     N'App',    N'TXN-0004', 34),

-- Partial payments
(5,  3, '2025-11-10T12:00:00', 2000.00, N'Bank',   N'Bank',   N'TXN-0005', 35),
(6,  3, '2025-11-20T13:30:00', 1500.00, N'Online', N'App',    N'TXN-0006', 35),
(7,  8, '2025-11-12T10:05:00', 2500.00, N'Cash',   N'Branch', N'TXN-0007', 36),
(8,  8, '2025-11-25T16:40:00', 2000.00, N'Card',   N'Branch', N'TXN-0008', 37),

-- One payment against pending bills
(9,  1, '2025-11-15T09:50:00', 1500.00, N'Online', N'App',    N'TXN-0009', 38),
(10, 5, '2025-11-18T14:10:00', 5000.00, N'Bank',   N'Bank',   N'TXN-0010', 39);

SET IDENTITY_INSERT dbo.PAYMENT OFF;


 /* ===========================
    17) COMPLAINT (10)
    status CHECK: Open/In_Progress/Resolved/Closed/Pending_Investigation
    =========================== */
SET IDENTITY_INSERT dbo.COMPLAINT ON;

INSERT INTO dbo.COMPLAINT
(complaint_id, customer_id, connection_id, meter_id, complaint_type, description, created_date, status, logged_by_staff_id, assigned_staff_id, resolved_date)
VALUES
(1, 1, 1, 2, N'High_Bill', N'Customer reports high electricity bill for October.', '2025-11-03T09:00:00', N'In_Progress', 3, 21, NULL),
(2, 2, 3, 5, N'Meter_Issue', N'Net meter display flickering intermittently.', '2025-11-04T10:00:00', N'Open', 5, 22, NULL),
(3, 3, 5, 7, N'No_Supply', N'Factory power interruption reported.', '2025-11-05T11:00:00', N'Pending_Investigation', 6, 23, NULL),
(4, 4, 6, 9, N'High_Bill', N'School requests bill re-check due to special tariff.', '2025-11-06T12:00:00', N'Open', 7, 24, NULL),
(5, 5, 8, 11, N'Meter_Issue', N'Export reading suspiciously low.', '2025-11-07T13:00:00', N'In_Progress', 8, 25, NULL),
(6, 6, 9, 12, N'No_Supply', N'Voltage fluctuation reported.', '2025-11-08T14:00:00', N'Resolved', 9, 26, '2025-11-10T10:30:00'),
(7, 7,10, 13, N'High_Bill', N'Customer claims low use but bill seems high.', '2025-11-09T15:00:00', N'Closed', 1, 27, '2025-11-12T09:00:00'),
(8, 8,11, 14, N'Meter_Issue', N'Smart meter not syncing.', '2025-11-10T16:00:00', N'Open', 2, 28, NULL),
(9, 10,14, 17, N'No_Supply', N'Factory outage complaint.', '2025-11-11T17:00:00', N'In_Progress', 3, 29, NULL),
(10,11,15, 18, N'High_Bill', N'Clinic requests subsidy eligibility check.', '2025-11-12T18:00:00', N'Open', 4, 30, NULL);

SET IDENTITY_INSERT dbo.COMPLAINT OFF;


 /* ===========================
    18) OUTAGE (10)
    utility_type: Electricity/Water/Gas
    outage_type: Planned/Unplanned
    =========================== */
SET IDENTITY_INSERT dbo.OUTAGE ON;

INSERT INTO dbo.OUTAGE
(outage_id, zone_id, utility_type, outage_type, start_time, end_time, reason, created_by_staff_id)
VALUES
(1, 1, N'Electricity', N'Planned',   '2025-11-01T01:00:00', '2025-11-01T04:00:00', N'Maintenance on feeder line', 41),
(2, 2, N'Electricity', N'Unplanned', '2025-11-03T19:30:00', '2025-11-03T21:00:00', N'Breaker trip', 42),
(3, 3, N'Water',       N'Planned',   '2025-11-05T09:00:00', '2025-11-05T12:00:00', N'Pipeline repair', 43),
(4, 4, N'Water',       N'Unplanned', '2025-11-06T14:10:00', '2025-11-06T16:30:00', N'Pump failure', 44),
(5, 5, N'Electricity', N'Planned',   '2025-11-07T22:00:00', '2025-11-08T02:00:00', N'Substation work', 45),
(6, 6, N'Electricity', N'Unplanned', '2025-11-09T18:00:00', '2025-11-09T20:00:00', N'Storm damage', 46),
(7, 7, N'Water',       N'Planned',   '2025-11-10T08:00:00', '2025-11-10T11:00:00', N'Valve replacement', 47),
(8, 8, N'Gas',         N'Unplanned', '2025-11-11T10:00:00', '2025-11-11T12:00:00', N'Leak investigation', 48),
(9, 9, N'Electricity', N'Unplanned', '2025-11-12T20:00:00', '2025-11-12T22:00:00', N'Line fault', 49),
(10,10,N'Electricity', N'Planned',   '2025-11-13T01:00:00', '2025-11-13T03:00:00', N'Transformer oil test', 50);

SET IDENTITY_INSERT dbo.OUTAGE OFF;


 /* ===========================
    19) DISCONNECTION_ORDER (10)
    reason CHECK: Non_Payment/Fraud/Customer_Request/Safety
    status CHECK: Pending/Completed/Cancelled
    =========================== */
SET IDENTITY_INSERT dbo.DISCONNECTION_ORDER ON;

INSERT INTO dbo.DISCONNECTION_ORDER
(disconnection_id, meter_id, reason, issue_date, scheduled_date, executed_date, status, created_by_staff_id, executed_by_staff_id)
VALUES
(1,  12, N'Non_Payment',      '2025-11-15','2025-11-18','2025-11-18',N'Completed', 1, 21),
(2,  13, N'Non_Payment',      '2025-11-15','2025-11-18','2025-11-18',N'Completed', 2, 22),
(3,  16, N'Safety',           '2025-11-16','2025-11-19','2025-11-19',N'Completed', 3, 23),
(4,  17, N'Fraud',            '2025-11-16','2025-11-20','2025-11-20',N'Completed', 5, 24),
(5,  18, N'Customer_Request', '2025-11-17','2025-11-21','2025-11-21',N'Completed', 6, 25),
(6,  7,  N'Non_Payment',      '2025-11-17','2025-11-22','2025-11-22',N'Completed', 7, 26),
(7,  9,  N'Non_Payment',      '2025-11-18','2025-11-23','2025-11-23',N'Completed', 8, 27),
(8,  11, N'Safety',           '2025-11-18','2025-11-24','2025-11-24',N'Completed', 9, 28),
(9,  3,  N'Customer_Request', '2025-11-19','2025-11-25','2025-11-25',N'Completed', 10,29),
(10, 10, N'Non_Payment',      '2025-11-19','2025-11-26','2025-11-26',N'Completed', 1, 30);

SET IDENTITY_INSERT dbo.DISCONNECTION_ORDER OFF;


 /* ===========================
    20) RECONNECTION (10)
    =========================== */
SET IDENTITY_INSERT dbo.RECONNECTION ON;

INSERT INTO dbo.RECONNECTION
(reconnection_id, meter_id, reconnection_date, reconnection_fee, processed_by_staff_id)
VALUES
(1,  12, '2025-11-20', 1500.00, 2),
(2,  13, '2025-11-20', 1500.00, 3),
(3,  16, '2025-11-21', 2000.00, 4),
(4,  17, '2025-11-22', 2500.00, 5),
(5,  18, '2025-11-22', 1500.00, 6),
(6,  7,  '2025-11-23', 5000.00, 7),
(7,  9,  '2025-11-24', 2000.00, 8),
(8,  11, '2025-11-24', 2000.00, 9),
(9,  3,  '2025-11-25', 1200.00, 10),
(10, 10, '2025-11-26', 1200.00, 1);

SET IDENTITY_INSERT dbo.RECONNECTION OFF;


 /* ===========================
    21) REPORT_REQUEST (10) - params_json validated by ISJSON in CHECK
    =========================== */
SET IDENTITY_INSERT dbo.REPORT_REQUEST ON;

INSERT INTO dbo.REPORT_REQUEST
(report_request_id, requested_by_staff_id, requested_at, report_type, params_json)
VALUES
(1,  41, '2025-11-01T09:00:00', N'MonthlyRevenue', N'{"month":"2025-10","utility":"Electricity"}'),
(2,  42, '2025-11-02T09:30:00', N'UnpaidBills',    N'{"zone_id":6,"as_of":"2025-11-02"}'),
(3,  43, '2025-11-03T10:00:00', N'Defaulters',     N'{"as_of":"2025-11-03","min_outstanding":1000}'),
(4,  44, '2025-11-04T10:30:00', N'ConsumptionByZone', N'{"period_start":"2025-10-01","period_end":"2025-10-31"}'),
(5,  45, '2025-11-05T11:00:00', N'SolarExportSummary', N'{"zone_id":1,"period":"2025-10"}'),
(6,  46, '2025-11-06T11:30:00', N'ComplaintsOpen', N'{"status":"Open"}'),
(7,  47, '2025-11-07T12:00:00', N'OutageImpact',   N'{"zone_id":6,"date":"2025-11-09"}'),
(8,  48, '2025-11-08T12:30:00', N'PaymentChannelMix', N'{"month":"2025-11"}'),
(9,  49, '2025-11-09T13:00:00', N'TariffAudit',    N'{"as_of":"2025-11-09"}'),
(10, 50, '2025-11-10T13:30:00', N'SubsidyUtilization', N'{"month":"2025-10"}');

SET IDENTITY_INSERT dbo.REPORT_REQUEST OFF;


/* ===========================
   Done
   =========================== */

COMMIT;
PRINT 'Sample data inserted successfully (10+ records per table).';
