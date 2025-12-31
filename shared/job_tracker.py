"""
Lightweight job tracker for pipeline status updates.
No containers needed - just import and use!
Works with any PostgreSQL database.
"""
import logging
import psycopg2
from psycopg2 import pool
from psycopg2.extras import Json
from typing import Optional, Dict, Any
import os


logger = logging.getLogger(__name__)


class SimpleJobTracker:
    """Standalone job tracker - works without dependency injection"""
    
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
        status: str,  # 'running', 'completed', 'failed'
        stage: str,   # 'ingestion', 'preprocessing', 'forecasting', 'anomaly'
        error_message: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """
        Update pipeline job status in database.
        
        Usage:
            SimpleJobTracker.update_status(
                job_id='job123',
                series_id='AAPL',
                status='running',
                stage='ingestion'
            )
        """
        conn = None
        cursor = None
        try:
            pool_instance = cls.get_pool()
            conn = pool_instance.getconn()
            cursor = conn.cursor()
            
            # Use psycopg2.extras.Json for proper JSON handling
            cursor.execute("""
                INSERT INTO pipeline_jobs 
                    (job_id, series_id, status, stage, error_message, metadata, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (job_id) 
                DO UPDATE SET
                    status = EXCLUDED.status,
                    stage = EXCLUDED.stage,
                    error_message = EXCLUDED.error_message,
                    metadata = CASE 
                        WHEN EXCLUDED.metadata IS NOT NULL AND pipeline_jobs.metadata IS NOT NULL 
                        THEN pipeline_jobs.metadata || EXCLUDED.metadata
                        ELSE COALESCE(EXCLUDED.metadata, pipeline_jobs.metadata)
                    END,
                    updated_at = CURRENT_TIMESTAMP
            """, (
                job_id,
                series_id,
                status,
                stage,
                error_message,
                Json(metadata) if metadata else None
            ))
            
            conn.commit()
            logger.info(f"Job {job_id}: {status} at {stage}")
            
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
    def close_pool(cls):
        """Close all connections in the pool (call on shutdown)"""
        if cls._pool is not None:
            cls._pool.closeall()
            logger.info("Job tracker database pool closed")
            cls._pool = None
