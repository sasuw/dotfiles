# Single source of truth for the Maven versions used across this repo.
# Sorted to load before 01-maven-path.sh, which consumes these values.
# Optional personal consumers can also use them. Do not redefine them elsewhere.

# Default Maven 3 / Maven 4 lines.
export maven3_version=3.10.0
export maven4_version=4.0.0-rc-6

# Older versions are available for optional personal consumers not shipped here.
export maven36_version=3.6.3
export maven38_version=3.8.8
