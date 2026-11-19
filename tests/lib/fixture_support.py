"""Keep suite-level setup/runner exceptions, including failed evidence copies."""

from contextlib import contextmanager
import shutil
import sys
import tempfile


@contextmanager
def setup_evidence(*, prefix):
    temporary = tempfile.mkdtemp(prefix=prefix)
    try:
        yield temporary
    except BaseException:
        print(f"Failed fixtures preserved at {temporary}", file=sys.stderr)
        raise
    else:
        try:
            shutil.rmtree(temporary)
        except OSError:
            print(f"Fixture cleanup failed; retained: {temporary}", file=sys.stderr)
            raise
