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
                // TMPDIR экспортируется во все стадии. Если каталога нет,
                // pip падает на распаковке — создаём заранее.
                sh 'mkdir -p "$TMPDIR"'
                sh 'rm -rf reports && mkdir -p reports'
                sh '${PYTHON} -m pip install --ignore-installed -r requirements.txt'
                sh '${PYTHON} -m pip install --ignore-installed -r requirements-dev.txt'
            }
        }

        // Каждая стадия всегда пишет свой exit code в reports/stage_*.
        // Падение не роняет build — итог определяет стадия Final Verdict
        // по агрегированному отчёту, где учтены ВСЕ стадии сразу.
        stage('Fast Checks Replay') { steps { sh 'set +e; bash scripts/checks.sh > reports/fast.log 2>&1; echo $? > reports/stage_fast_checks' } }
        stage('Unit Tests')         { steps { sh 'set +e; pytest tests/ -q --tb=short > reports/unit.log 2>&1; echo $? > reports/stage_unit' } }
        stage('Integration Tests')  { steps { sh 'set +e; bash scripts/integration_test.sh > reports/integration.log 2>&1; echo $? > reports/stage_integration' } }
        stage('Security Scan')      { steps { sh 'set +e; bandit -q -r server.py voicegen.py model_loader.py > reports/security.log 2>&1; echo $? > reports/stage_security' } }
        stage('Load Test')          { steps { sh 'set +e; bash scripts/load_test.sh > reports/load.log 2>&1; echo $? > reports/stage_load' } }

        stage('Aggregate Report') {
            steps {
                // set +e: агрегатор возвращает 1 при провале, но ронять
                // стадию нельзя — тогда archiveArtifacts не выполнится и
                // артефакт с разбором провала не сохранится. Вердикт
                // объявляет следующая стадия.
                sh 'set +e; ${PYTHON} scripts/aggregate_report.py'
                archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            }
        }

        stage('Final Verdict') { steps { sh 'test -f reports/verdict-ok' } }
    }
    post {
        always {
            echo "Unified report: artifact reports/ci-report.json"
        }
        success { echo '✅ all local gates and server gates passed' }
        failure { echo '❌ see unified report artifact reports/ci-report.json' }
    }
}
