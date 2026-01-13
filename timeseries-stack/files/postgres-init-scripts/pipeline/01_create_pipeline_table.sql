-- Create pipeline jobs tracking table
CREATE TABLE IF NOT EXISTS pipeline_jobs (
    job_id VARCHAR(255) PRIMARY KEY,
    series_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,  -- 'running', 'completed', 'failed'
    stage VARCHAR(50),  -- 'ingestion', 'preprocessing', 'forecasting', 'anomaly'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT,
    metadata JSONB
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_series ON pipeline_jobs(series_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_status ON pipeline_jobs(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_created ON pipeline_jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_updated ON pipeline_jobs(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_stage ON pipeline_jobs(stage);

-- Create a composite index for common queries
CREATE INDEX IF NOT EXISTS idx_pipeline_jobs_series_status ON pipeline_jobs(series_id, status);

-- Add a comment for documentation
COMMENT ON TABLE pipeline_jobs IS 'Tracks the status of pipeline jobs across all microservices';
COMMENT ON COLUMN pipeline_jobs.status IS 'Job status: running, completed, or failed';
COMMENT ON COLUMN pipeline_jobs.stage IS 'Pipeline stage: ingestion, preprocessing, forecasting, or anomaly';

-- Optional: Create a view for active jobs
CREATE OR REPLACE VIEW active_pipeline_jobs AS
SELECT 
    job_id,
    series_id,
    status,
    stage,
    created_at,
    updated_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) AS running_seconds,
    error_message
FROM pipeline_jobs
WHERE status = 'running'
ORDER BY created_at DESC;

-- Optional: Create a view for job history with duration
CREATE OR REPLACE VIEW pipeline_job_history AS
SELECT 
    job_id,
    series_id,
    status,
    stage,
    created_at,
    updated_at,
    EXTRACT(EPOCH FROM (updated_at - created_at)) AS duration_seconds,
    error_message,
    metadata
FROM pipeline_jobs
ORDER BY created_at DESC;

-- Grant permissions (if needed)
GRANT ALL PRIVILEGES ON TABLE pipeline_jobs TO tsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tsuser;
