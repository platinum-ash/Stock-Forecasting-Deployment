-- Stats Service Status Tracking Table
CREATE TABLE IF NOT EXISTS stats_job_status (
    id SERIAL PRIMARY KEY,
    series_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,  -- 'started', 'done', 'failed', 'no_data'
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_stats_series_id ON stats_job_status(series_id);
CREATE INDEX IF NOT EXISTS idx_stats_status ON stats_job_status(status);
CREATE INDEX IF NOT EXISTS idx_stats_created_at ON stats_job_status(created_at DESC);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE stats_job_status TO tsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tsuser;
