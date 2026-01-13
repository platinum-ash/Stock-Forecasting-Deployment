"""
Lightweight job tracker for pipeline status updates.
Tracks each stage separately for better visibility.
"""
import logging
import psycopg2
from psycopg2 import pool
from psycopg2.extras import Json
from typing import Optional, Dict, Any
import os

logger = logging.getLogger(__name__)

class SimpleJobTracker:
    """Standalone job tracker - tracks each pipeline stage separately"""
    
    _pool = None
    
    @classmethod
    def get_pool(cls):
        """Get or create database connection pool"""
        if cls._pool is None:
            try:
                cls._pool = pool.ThreadedConnectionPool(
                    minconn=1,
                    maxconn=5,
                    host=os.getenv("PIPELINE_DATABASE_HOST", "postgres-pipeline"),
                    port=int(os.getenv("PIPELINE_DATABASE_PORT", "5432")),
                    database=os.getenv("PIPELINE_DATABASE_NAME", "pipeline"),
                    user=os.getenv("PIPELINE_DATABASE_USER", "tsuser"),
                    password=os.getenv("PIPELINE_DATABASE_PASSWORD", "ts_password"),
                    connect_timeout=10
                )
                logger.info("Job tracker database pool initialized")
            except Exception as e:
                logger.error(f"Failed to create database pool: {e}")
                raise
        return cls._pool
    
    @classmethod
    def update_status(
        cls,
        job_id: str,
        series_id: str,
        status: str,  # 'pending', 'running', 'completed', 'failed'
        stage: str,   # 'ingestion', 'preprocessing', 'forecasting', 'anomaly', 'stats'
        error_message: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Update pipeline stage status in database.
        Each stage gets its own row - no more overwriting!
        
        Usage:
            # Start ingestion
            SimpleJobTracker.update_status(
                job_id='job123',
                series_id='AAPL',
                status='running',
                stage='ingestion'
            )
            
            # Complete ingestion
            SimpleJobTracker.update_status(
                job_id='job123',
                series_id='AAPL',
                status='completed',
                stage='ingestion'
            )
            
            # Start preprocessing
            SimpleJobTracker.update_status(
                job_id='job123',
                series_id='AAPL',
                status='running',
                stage='preprocessing'
            )
        """
        conn = None
        cursor = None
        try:
            pool_instance = cls.get_pool()
            conn = pool_instance.getconn()
            cursor = conn.cursor()
            
            # Insert or update specific stage
            cursor.execute("""
                INSERT INTO pipeline_job_stages 
                    (job_id, series_id, stage, status, error_message, metadata, started_at, completed_at)
                VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, 
                        CASE WHEN %s IN ('completed', 'failed') THEN CURRENT_TIMESTAMP ELSE NULL END)
                ON CONFLICT (job_id, stage) 
                DO UPDATE SET
                    status = EXCLUDED.status,
                    error_message = EXCLUDED.error_message,
                    metadata = CASE 
                        WHEN EXCLUDED.metadata IS NOT NULL AND pipeline_job_stages.metadata IS NOT NULL 
                        THEN pipeline_job_stages.metadata || EXCLUDED.metadata
                        ELSE COALESCE(EXCLUDED.metadata, pipeline_job_stages.metadata)
                    END,
                    completed_at = CASE 
                        WHEN EXCLUDED.status IN ('completed', 'failed') THEN CURRENT_TIMESTAMP 
                        ELSE pipeline_job_stages.completed_at
                    END
            """, (
                job_id,
                series_id,
                stage,
                status,
                error_message,
                Json(metadata) if metadata else None,
                status
            ))
            
            conn.commit()
            logger.info(f"Job {job_id} - Stage {stage}: {status}")
            
        except psycopg2.Error as e:
            logger.error(f"Database error updating job status: {e}")
            if conn:
                conn.rollback()
        except Exception as e:
            logger.error(f"Failed to update job status: {e}")
            if conn:
                conn.rollback()
        finally:
            if cursor:
                cursor.close()
            if conn:
                pool_instance.putconn(conn)
    
    @classmethod
    def start_stage(cls, job_id: str, series_id: str, stage: str, metadata: Optional[Dict[str, Any]] = None):
        """Convenience method to start a stage"""
        cls.update_status(job_id, series_id, 'running', stage, metadata=metadata)
    
    @classmethod
    def complete_stage(cls, job_id: str, series_id: str, stage: str, metadata: Optional[Dict[str, Any]] = None):
        """Convenience method to complete a stage"""
        cls.update_status(job_id, series_id, 'completed', stage, metadata=metadata)
    
    @classmethod
    def fail_stage(cls, job_id: str, series_id: str, stage: str, error_message: str, metadata: Optional[Dict[str, Any]] = None):
        """Convenience method to fail a stage"""
        cls.update_status(job_id, series_id, 'failed', stage, error_message=error_message, metadata=metadata)
    
    @classmethod
    def close_pool(cls):
        """Close all connections in the pool (call on shutdown)"""
        if cls._pool is not None:
            cls._pool.closeall()
            logger.info("Job tracker database pool closed")
            cls._pool = None
