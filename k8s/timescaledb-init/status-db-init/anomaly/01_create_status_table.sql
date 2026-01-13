-- Anomaly Service Status Tracking Table
CREATE TABLE IF NOT EXISTS anomaly_job_status (
    id SERIAL PRIMARY KEY,
    series_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,  -- 'started', 'done', 'failed', 'no_data'
    anomalies_found INT,
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_anomaly_series_id ON anomaly_job_status(series_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_status ON anomaly_job_status(status);
CREATE INDEX IF NOT EXISTS idx_anomaly_created_at ON anomaly_job_status(created_at DESC);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE anomaly_job_status TO tsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tsuser;
