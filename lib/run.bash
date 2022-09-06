#!/bin/bash

compose_cleanup() {
  if [[ "$(plugin_read_config GRACEFUL_SHUTDOWN 'false')" == "false" ]]; then
    # Send all containers a SIGKILL
    run_docker_compose kill || true
  else
    # Send all containers a friendly SIGTERM, followed by a SIGKILL after exceeding the stop_grace_period
    run_docker_compose stop || true
  fi

  # `compose down` doesn't support force removing images
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    run_docker_compose rm --force -v || true
  else
    run_docker_compose rm --force || true
  fi

  # Stop and remove all the linked services and network
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    run_docker_compose down --volumes || true
  else
    run_docker_compose down || true
  fi
}

# docker-compose's -v arguments don't do local path expansion like the .yml
# versions do. So we add very simple support, for the common and basic case.
#
# "./foo:/foo" => "/buildkite/builds/.../foo:/foo"
expand_relative_volume_path() {
  local path="$1"
  local pwd="$PWD"

  # docker-compose's -v expects native paths on windows, so convert back.
  #
  # "/c/Users/..." => "C:\Users\..."
  if is_windows ; then
    pwd="$(cygpath -w "$PWD")"
  fi

  echo "${path/.\//$pwd/}"
}
