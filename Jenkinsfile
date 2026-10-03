pipeline {
    agent any
    environment {
        PYTHON = 'python3'
        TMPDIR = '/var/tmp/pip-tmp'
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Setup Environment') {
            steps {
                sh '${PYTHON} -m pip install --ignore-installed -r requirements.txt'
                sh '${PYTHON} -m pip install --ignore-installed -r requirements-dev.txt'
                sh 'mkdir -p reports'
            }
        }
        stage('Fast Checks Replay') { steps { sh 'set +e; bash scripts/checks.sh > reports/fast.log 2>&1; echo $? > reports/stage_fast_checks' } }
        stage('Unit Tests')         { steps { sh 'set +e; pytest tests/ -q --tb=short > reports/unit.log 2>&1; echo $? > reports/stage_unit' } }
        stage('Integration Tests')  { steps { sh 'set +e; bash scripts/integration_test.sh > reports/integration.log 2>&1; echo $? > reports/stage_integration' } }
        stage('Security Scan')      { steps { sh 'set +e; bandit -q -r server.py voicegen.py model_loader.py > reports/security.log 2>&1; echo $? > reports/stage_security' } }
        stage('Load Test')          { steps { sh 'set +e; bash scripts/load_test.sh > reports/load.log 2>&1; echo $? > reports/stage_load' } }
        stage('Aggregate Report') {
            steps {
                sh '${PYTHON} scripts/aggregate_report.py'
                archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            }
        }
        stage('Final Verdict') { steps { sh 'test -f reports/verdict-ok' } }
    }
    post {
        success { echo '✅ Unified report: artifact reports/ci-report.json' }
        failure { echo '❌ See unified report artifact reports/ci-report.json' }
    }
}