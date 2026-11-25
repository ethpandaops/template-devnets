# mitogen (pinned in uv.lock) is importable from the venv, so re-export its strategy
# instead of pointing ansible.cfg at a Python-version-specific site-packages path.
from ansible_mitogen.plugins.strategy.mitogen_free import StrategyModule  # noqa: F401

import ansible_mitogen.loaders
import ansible_mitogen.strategy as _strategy
from ansible.playbook.play_context import PlayContext

# Since ansible-core 2.19 the executor writes the resolved plugin name back onto the
# task (task.connection = "mitogen_ssh"), so from the second loop item on the play
# context's connection is "mitogen_ssh". mitogen (<= 0.3.55) redirects "local" to
# "mitogen_local" only when that value is "ssh", "local", ..., so a looped
# ansible.posix.synchronize gets ansible's plain local connection and fails with
# "'Connection' object has no attribute 'get_good_temp_dir'" (validator_keys role).
_wrap_connection_loader = _strategy.wrap_connection_loader__get_with_context


def _wrap_connection_loader__get_with_context(name, *args, **kwargs):
    play_context = args[0] if args and isinstance(args[0], PlayContext) else None
    if (play_context is not None and str(play_context.connection).startswith("mitogen_")
            and name in _strategy.REDIRECTED_CONNECTION_PLUGINS):
        return ansible_mitogen.loaders.connection_loader__get_with_context("mitogen_" + name, *args, **kwargs)
    return _wrap_connection_loader(name, *args, **kwargs)


# Looked up as a module global each time the strategy installs its wrappers.
_strategy.wrap_connection_loader__get_with_context = _wrap_connection_loader__get_with_context
