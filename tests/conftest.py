import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The Flask app and the Lambda live in separate folders without packaging
sys.path.insert(0, str(ROOT / 'app'))
sys.path.insert(0, str(ROOT / 'terraform'))

# Fake credentials so a test can never reach a real AWS account, even if a code path calls AWS by mistake
for var in ('AWS_PROFILE', 'AWS_SESSION_TOKEN', 'AWS_SECURITY_TOKEN'):
    os.environ.pop(var, None)
os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
os.environ['AWS_CONFIG_FILE'] = os.devnull
os.environ['AWS_SHARED_CREDENTIALS_FILE'] = os.devnull
