# mitogen (pinned in uv.lock) is importable from the venv, so re-export its strategy
# instead of pointing ansible.cfg at a Python-version-specific site-packages path.
from ansible_mitogen.plugins.strategy.mitogen_free import StrategyModule  # noqa: F401
