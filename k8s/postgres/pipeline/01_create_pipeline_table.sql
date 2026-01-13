-- Drop old table and create new pipeline_job_stages table
DROP TABLE IF EXISTS pipeline_jobs CASCADE;

-- New table: Track each stage separately
CREATE TABLE IF NOT EXISTS pipeline_job_stages (
    id SERIAL PRIMARY KEY,
    job_id VARCHAR(255) NOT NULL,
    series_id VARCHAR(255) NOT NULL,
    stage VARCHAR(50) NOT NULL,  -- 'ingestion', 'preprocessing', 'forecasting', 'anomaly', 'stats'
    status VARCHAR(50) NOT NULL,  -- 'pending', 'running', 'completed', 'failed'
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB,
    UNIQUE(job_id, stage)  -- One row per job per stage
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_job_stages_job_id ON pipeline_job_stages(job_id);
CREATE INDEX IF NOT EXISTS idx_job_stages_series ON pipeline_job_stages(series_id);
CREATE INDEX IF NOT EXISTS idx_job_stages_status ON pipeline_job_stages(status);
CREATE INDEX IF NOT EXISTS idx_job_stages_stage ON pipeline_job_stages(stage);
CREATE INDEX IF NOT EXISTS idx_job_stages_started ON pipeline_job_stages(started_at DESC);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_job_stages_job_status ON pipeline_job_stages(job_id, status);
CREATE INDEX IF NOT EXISTS idx_job_stages_series_status ON pipeline_job_stages(series_id, status);

-- View: Overall job status (aggregated from all stages)
CREATE OR REPLACE VIEW pipeline_jobs_overview AS
SELECT 
    job_id,
    series_id,
    MIN(started_at) as started_at,
    MAX(completed_at) as completed_at,
    CASE 
        WHEN COUNT(*) FILTER (WHERE status = 'failed') > 0 THEN 'failed'
        WHEN COUNT(*) FILTER (WHERE status = 'running') > 0 THEN 'running'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*) THEN 'completed'
        ELSE 'partial'
    END as overall_status,
    COUNT(*) as total_stages,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_stages,
    COUNT(*) FILTER (WHERE status = 'running') as running_stages,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_stages,
    EXTRACT(EPOCH FROM (COALESCE(MAX(completed_at), NOW()) - MIN(started_at))) as duration_seconds,
    array_agg(stage ORDER BY started_at) as stages,
    array_agg(status ORDER BY started_at) as stage_statuses
FROM pipeline_job_stages
GROUP BY job_id, series_id
ORDER BY started_at DESC;

-- View: Active pipeline jobs with stage details
CREATE OR REPLACE VIEW active_pipeline_jobs_detailed AS
SELECT 
    pjs.job_id,
    pjs.series_id,
    pjs.stage,
    pjs.status,
    pjs.started_at,
    EXTRACT(EPOCH FROM (NOW() - pjs.started_at)) AS running_seconds,
    pjs.error_message
FROM pipeline_job_stages pjs
WHERE pjs.status IN ('running', 'pending')
ORDER BY pjs.started_at DESC, pjs.stage;

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE pipeline_job_stages TO tsuser;
GRANT ALL PRIVILEGES ON SEQUENCE pipeline_job_stages_id_seq TO tsuser;
GRANT SELECT ON pipeline_jobs_overview TO tsuser;
GRANT SELECT ON active_pipeline_jobs_detailed TO tsuser;

-- Comments
COMMENT ON TABLE pipeline_job_stages IS 'Tracks individual stages of pipeline jobs across all microservices';
COMMENT ON COLUMN pipeline_job_stages.status IS 'Stage status: pending, running, completed, or failed';
COMMENT ON COLUMN pipeline_job_stages.stage IS 'Pipeline stage: ingestion, preprocessing, forecasting, anomaly, or stats';
