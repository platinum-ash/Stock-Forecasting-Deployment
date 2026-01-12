-- enable TimescaleDB extension (needed before create_hypertable)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

 
CREATE TABLE IF NOT EXISTS forecasts (
    id SERIAL,
    series_id VARCHAR(255) NOT NULL,
    method VARCHAR(50) NOT NULL,
    horizon INT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    mape FLOAT,
    rmse FLOAT,
    metadata JSONB,
    forecast_data JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS model_metrics (
    id SERIAL PRIMARY KEY,
    series_id VARCHAR(255) NOT NULL,
    method VARCHAR(50) NOT NULL,
    train_rmse FLOAT NOT NULL,
    test_rmse FLOAT NOT NULL,
    train_mape FLOAT NOT NULL,
    test_mape FLOAT NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_trained TIMESTAMP NOT NULL,
    training_samples INT NOT NULL,
    UNIQUE(series_id, method)
);

-- now create hypertables
SELECT create_hypertable('forecasts', 'created_at', if_not_exists => TRUE);
-- SELECT create_hypertable('model_metrics', 'last_trained', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_series_method ON forecasts (series_id, method);

CREATE INDEX IF NOT EXISTS idx_forecasts_id ON forecasts (id);

CREATE INDEX IF NOT EXISTS idx_created_at ON forecasts (created_at);

CREATE INDEX IF NOT EXISTS idx_model_series_method ON model_metrics (series_id, method);
 
