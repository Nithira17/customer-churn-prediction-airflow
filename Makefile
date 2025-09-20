.PHONY: all clean install setup-dirs train-pipeline train-sklearn train-pyspark test-pyspark data-pipeline data-pipeline-rebuild streaming-inference run-all mlflow-ui stop-all \
airflow-init airflow-standalone airflow-start airflow-webserver airflow-scheduler airflow-dags-list \
airflow-test-data-pipeline airflow-test-training-pipeline airflow-test-inference-pipeline \
airflow-clean airflow-delete-dags airflow-kill airflow-trigger-all airflow-health airflow-reset re-run-all help

# Use Windows venv activation
PYTHON = python
VENV = .venv\Scripts\activate.bat
MLFLOW_PORT ?= 5001

# Default target
all: help

help:
	@echo Available targets:
	@echo   make install             - Install project dependencies and set up environment
	@echo   make setup-dirs          - Create necessary directories for pipelines
	@echo   make data-pipeline       - Run the data pipeline
	@echo   make train-pipeline      - Run the training pipeline (PySpark MLlib)
	@echo   make train-sklearn       - Run the training pipeline (scikit-learn)
	@echo   make train-pyspark       - Run the training pipeline (PySpark MLlib)
	@echo   make test-pyspark        - Test PySpark MLlib pipeline
	@echo   make streaming-inference - Run the streaming inference pipeline with the sample JSON
	@echo   make run-all             - Run all pipelines in sequence
	@echo   make clean               - Clean up artifacts
	@echo   make mlflow-ui           - Launch the MLflow UI on localhost:$(MLFLOW_PORT)
	@echo   make stop-all            - Stop MLflow servers on port $(MLFLOW_PORT)
	@echo   make sync-dags-to-wsl    - Sync DAG files from Windows to WSL2 Airflow
	@echo   make airflow-start-wsl   - Start Airflow in WSL2
	@echo   make airflow-status      - Check if Airflow is running
	@echo   make airflow-stop-wsl    - Stop Airflow in WSL2
	@echo   make airflow-deploy      - Deploy DAGs to WSL2 Airflow

# Install project dependencies and set up environment (Windows)
install:
	@echo Installing project dependencies and setting up environment...
	@echo Creating virtual environment...
	$(PYTHON) -m venv .venv
	@echo Activating virtual environment and installing dependencies...
	$(VENV) && $(PYTHON) -m pip install --upgrade pip
	$(VENV) && $(PYTHON) -m pip install -r requirements.txt
	@echo Installation completed successfully!
	@echo To activate the virtual environment, run: .venv\Scripts\activate.bat

# Create necessary directories (Windows)
setup-dirs:
	@echo Creating necessary directories...
	@if not exist artifacts mkdir artifacts
	@if not exist artifacts\data mkdir artifacts\data
	@if not exist artifacts\models mkdir artifacts\models
	@if not exist artifacts\encode mkdir artifacts\encode
	@if not exist artifacts\mlflow_run_artifacts mkdir artifacts\mlflow_run_artifacts
	@if not exist artifacts\mlflow_training_artifacts mkdir artifacts\mlflow_training_artifacts
	@if not exist artifacts\inference_batches mkdir artifacts\inference_batches
	@if not exist data mkdir data
	@if not exist data\processed mkdir data\processed
	@if not exist data\raw mkdir data\raw
	@echo Directories created successfully!

# Clean up (Windows)
clean:
	@echo Cleaning up artifacts...
	@if exist artifacts rmdir /s /q artifacts
	@if exist mlruns rmdir /s /q mlruns
	@echo Cleanup completed!

# Run data pipeline with PySpark environment variables
data-pipeline: setup-dirs
	@echo Start running data pipeline...
	.venv\Scripts\activate.bat && set PYSPARK_PYTHON=.venv\Scripts\python.exe && set PYSPARK_DRIVER_PYTHON=.venv\Scripts\python.exe && python pipelines\data_pipeline.py
	@echo Data pipeline completed successfully!

# Force rebuild for data pipeline
data-pipeline-rebuild: setup-dirs
	$(VENV) && $(PYTHON) -c "from pipelines.data_pipeline import data_pipeline; data_pipeline(force_rebuild=True)"

# Run training pipeline (PySpark MLlib by default)
train-pipeline: setup-dirs
	@echo Running PySpark MLlib training pipeline...
	$(VENV) && $(PYTHON) pipelines\training_pipeline.py

# Run training pipeline with scikit-learn
train-sklearn: setup-dirs
	@echo Running scikit-learn training pipeline...
	$(VENV) && set TRAINING_ENGINE=sklearn && $(PYTHON) pipelines\training_pipeline.py

# Run training pipeline with PySpark MLlib
train-pyspark: setup-dirs
	@echo Running PySpark MLlib training pipeline...
	$(VENV) && set TRAINING_ENGINE=pyspark && $(PYTHON) pipelines\training_pipeline.py

# Test PySpark MLlib pipeline
test-pyspark: setup-dirs
	@echo Testing PySpark MLlib pipeline...
	$(VENV) && $(PYTHON) test_pyspark_pipeline.py

# Run streaming inference pipeline with sample JSON
streaming-inference: setup-dirs
	@echo Running streaming inference pipeline with sample JSON...
	$(VENV) && $(PYTHON) pipelines\streaming_inference_pipeline.py

# Run all pipelines in sequence
run-all: setup-dirs
	@echo Running all pipelines in sequence...
	@echo ========================================
	@echo Step 1: Running data pipeline
	@echo ========================================
	$(VENV) && $(PYTHON) pipelines\data_pipeline.py
	@echo.
	@echo ========================================
	@echo Step 2: Running training pipeline
	@echo ========================================
	$(VENV) && $(PYTHON) pipelines\training_pipeline.py
	@echo.
	@echo ========================================
	@echo Step 3: Running streaming inference pipeline
	@echo ========================================
	$(VENV) && $(PYTHON) pipelines\streaming_inference_pipeline.py
	@echo.
	@echo ========================================
	@echo All pipelines completed successfully!
	@echo ========================================

# Launch MLflow UI (single worker recommended on Windows)
mlflow-ui:
	@echo Launching MLflow UI...
	@echo MLflow UI will be available at: http://localhost:$(MLFLOW_PORT)
	@echo Press Ctrl+C to stop the server
	$(VENV) && mlflow ui --host 127.0.0.1 --port $(MLFLOW_PORT) --workers 1

# Stop all running MLflow servers (Windows)
stop-all:
	@echo Stopping MLflow servers on port $(MLFLOW_PORT)...
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :$(MLFLOW_PORT)') do @taskkill /PID %%a /F >nul 2>&1
	@echo Done.

# ========================================================================================
# APACHE AIRFLOW ORCHESTRATION TARGETS (Windows)
# ========================================================================================

# Initialize Apache Airflow
airflow-init:
	@echo Initializing Apache Airflow...
	@if not exist .airflow mkdir .airflow
	@if not exist .airflow\dags mkdir .airflow\dags
	@if not exist .airflow\logs mkdir .airflow\logs
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && pip install "apache-airflow>=2.10.0,<3.0.0" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.9.txt"
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && pip install apache-airflow-providers-apache-spark
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow db migrate
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow users create -u admin -p admin -r Admin -e admin@example.com -f Admin -l User
	@for %%f in (dags\*.py) do copy /Y "%%f" ".airflow\dags\" >nul
	@echo Airflow initialized successfully!


# Start Airflow webserver
airflow-webserver:
	@echo Starting Airflow webserver on http://localhost:8080...
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow webserver --port 8080


# Start Airflow scheduler
airflow-scheduler:
	@echo Starting Airflow scheduler...
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow scheduler


# Start Airflow in standalone mode (simpler local dev)
airflow-standalone:
	@echo Starting Airflow in standalone mode...
	@echo Webserver will be available at http://localhost:8080
	@echo Login with: admin / admin
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow standalone


# Start webserver and scheduler in same console (best to use separate consoles on Windows)
airflow-start:
	@echo Starting Airflow webserver and scheduler...
	@echo (Tip: open two terminals and run 'make airflow-webserver' and 'make airflow-scheduler' separately.)
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && start cmd /c "airflow webserver --port 8080"
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && start cmd /c "airflow scheduler"


# List DAGs
airflow-dags-list:
	@echo Listing Airflow DAGs...
	@set "AIRFLOW_HOME=%CD%\.airflow" && call $(VENV) && airflow dags list


# Test DAG tasks
airflow-test-data-pipeline:
	@echo Testing data pipeline DAG task...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow tasks test data_pipeline_dag run_data_pipeline 2025-01-01

airflow-test-training-pipeline:
	@echo Testing training pipeline DAG task...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow tasks test training_pipeline_dag run_training_pipeline 2025-01-01

airflow-test-inference-pipeline:
	@echo Testing inference pipeline DAG task...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow tasks test inference_dag run_inference_pipeline 2025-01-01

# Clean Airflow database and logs
airflow-clean:
	@echo Cleaning Airflow database and logs...
	@if exist .airflow\airflow.db del /q .airflow\airflow.db
	@if exist .airflow\logs rmdir /s /q .airflow\logs
	@echo Cleaned.

# Delete all DAGs and hide example DAGs
airflow-delete-dags:
	@echo Stopping Airflow if running...
	@taskkill /IM airflow.exe /F >nul 2>&1 || echo No Airflow process found
	@echo Hiding example DAGs...
	@if exist .airflow\airflow.cfg powershell -Command "(Get-Content '.airflow\\airflow.cfg') -replace 'load_examples = True','load_examples = False' | Set-Content '.airflow\\airflow.cfg'"
	@echo Deleting project DAG files...
	@if exist .airflow\dags rmdir /s /q .airflow\dags
	@mkdir .airflow\dags
	@echo All DAGs deleted. Example DAGs will be hidden on next start.

# Kill all Airflow processes and free ports (8080, 8793, 8794)
airflow-kill:
	@echo Killing all Airflow processes...
	@for /f "tokens=2 delims=," %%p in ('powershell -Command "Get-Process | Where-Object {$$_.ProcessName -like '*airflow*'} | ForEach-Object {$$_.Id}"') do @taskkill /PID %%p /F >nul 2>&1
	@echo Freeing Airflow ports (8080, 8793, 8794)...
	@for %%P in (8080 8793 8794) do @for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%%P') do @taskkill /PID %%a /F >nul 2>&1
	@echo Done.

# Trigger all DAGs
airflow-trigger-all:
	@echo Triggering all DAGs...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow dags trigger data_pipeline_dag && \
	airflow dags trigger training_pipeline_dag && \
	airflow dags trigger inference_dag
	@echo All DAGs triggered! Check the Web UI at http://localhost:8080

# Health check
airflow-health:
	@echo Checking Airflow health endpoint...
	@curl -s http://localhost:8080/health || echo Airflow not responding
	@echo.
	@echo Checking running processes...
	@tasklist | findstr /I airflow || echo No Airflow processes found

# Reset Airflow database and fix login issues
airflow-reset:
	@echo Resetting Airflow database and fixing login issues...
	@$(MAKE) airflow-kill
	@echo Removing old database and logs...
	@if exist .airflow\airflow.db del /q .airflow\airflow.db
	@if exist .airflow\logs rmdir /s /q .airflow\logs
	@for /f "delims=" %%d in ('dir /s /b /ad ^| findstr /i \\__pycache__\\') do @rmdir /s /q "%%d"
	@for /f "delims=" %%f in ('dir /s /b *.pyc') do @del /q "%%f"
	@echo Reinitializing database...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow db migrate
	@echo Creating admin user...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow users create -u admin -f Admin -l User -p admin -r Admin -e admin@example.com
	@echo Copying DAGs...
	@if exist dags for %%f in (dags\*.py) do copy /Y "%%f" ".airflow\dags\" >nul
	@echo Airflow reset complete! Login: admin/admin
	@echo Start with: make airflow-standalone

# Complete reset and restart
re-run-all:
	@echo Starting complete system reset and restart...
	@$(MAKE) airflow-kill
	@echo Cleaning database, logs, and Python cache files...
	@if exist .airflow\airflow.db del /q .airflow\airflow.db
	@if exist .airflow\logs rmdir /s /q .airflow\logs
	@if exist .airflow\dags rmdir /s /q .airflow\dags
	@mkdir .airflow\dags
	@for /f "delims=" %%d in ('dir /s /b /ad ^| findstr /i \\__pycache__\\') do @rmdir /s /q "%%d"
	@for /f "delims=" %%f in ('dir /s /b *.pyc') do @del /q "%%f"
	@echo Reinitializing Airflow database...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow db migrate
	@echo Creating admin user (admin/admin)...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	airflow users create -u admin -f Admin -l User -p admin -r Admin -e admin@example.com >nul 2>&1 || echo Admin user may already exist
	@echo Copying fresh DAGs...
	@if exist dags for %%f in (dags\*.py) do copy /Y "%%f" ".airflow\dags\" >nul
	@echo Starting Airflow standalone...
	@set AIRFLOW_HOME=%CD%\.airflow && \
	$(VENV) && \
	start cmd /c "airflow standalone"
	@echo.
	@echo ==============================================
	@echo COMPLETE RESET AND RESTART FINISHED!
	@echo Web UI: http://localhost:8080
	@echo Login: admin / admin
	@echo ==============================================

# ========================================================================================
# APACHE AIRFLOW ORCHESTRATION TARGETS (WSL2 Integration)
# ========================================================================================

# Sync DAGs from Windows to WSL2
sync-dags-to-wsl:
	@echo Syncing DAGs from Windows to WSL2...
	@wsl -d Ubuntu mkdir -p /home/nithira17/airflow-class/.airflow/dags/
	@if exist dags for %%f in (dags\*.py) do wsl -d Ubuntu cp "/mnt/c/Users/hewaj/Desktop/Zuu Crew/Customer Churn Prediction - AirFlow/dags/%%~nxf" "/home/nithira17/airflow-class/.airflow/dags/"
	@echo DAGs synced successfully!
	@echo Access Airflow UI at: http://localhost:8080

# Start Airflow in WSL2 (opens new terminal)
airflow-start-wsl:
	@echo Starting Airflow in WSL2...
	@echo This will open a new WSL2 terminal window
	wsl -d Ubuntu -e bash -c "cd ~/airflow-class && source .venv/bin/activate && ./start_airflow.sh"

# Check if Airflow is running
airflow-status:
	@echo Checking Airflow status...
	@curl -s http://localhost:8080/health || echo Airflow is not running
	@echo.
	@echo If running, access at: http://localhost:8080

# Stop Airflow (kills WSL2 processes)
airflow-stop-wsl:
	@echo Stopping Airflow in WSL2...
	@wsl -d Ubuntu pkill -f airflow || echo No Airflow processes found
	@echo Airflow stopped.

# Complete Airflow workflow
airflow-deploy:
	@echo Deploying to Airflow...
	@$(MAKE) sync-dags-to-wsl
	@echo DAGs deployed! Start Airflow with: make airflow-start-wsl
	@echo Or manually run in WSL2: cd ~/airflow-class && ./start_airflow.sh