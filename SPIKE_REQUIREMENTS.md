# Spike Requirements

This spike is about discovering how to work with development environments based on docker, where the development instrumentation runs inside containers, having guardrails implemented such as read only root FS, controlled access to filesystem, non root users and so on.

Host utilization scenarios are:

- **H_W_0R**:  Windows with Rancher Desktop installed for all users
- **H_W_0U**:  Windows with Rancher Desktop installed for current user
- **H_M_0R**: Mac OS with Rancher Desktop installed for all users
- **H_M_0U**: Mac OS with Rancher Desktop installed for current user
- **L_M_0R**: Linux with Docker CE rootful installed for all users
- **L_M_0U**: Linux with Docker CE rootless installed for current user

Development environments are based on docker compose and contain one or more services, and each searvice may mount folders in the workspace, for example:

- workspace
  - code
    - java
      - java-project-1
    - scripts
      - service-1
        - entrypoint.sh
        - utility-2.sh
      - service-2
    - go
      - go-project-1
    - is
      - packages
      - java
  - run-configs
    - go-development-1
    - java-develoipment-2
    - go-test-3
      - data
        - db-1

etc

Ecah run config is a docker compose project mounting code folders as bind mounts according to need. we may also have data mounts, supporting development against services such as databases.

Specific to webMethods, we may have containers having microservices runtimes that mount packages at development time that are copied in the image at test time. Examples: work/repos/2l-wz-pack/03-envs , work/repos/5s-git-first-srv-dev-daf-edge-template/02-run-configs , work/repos/5s-pub-sub-with-mon-01/03.envs , work/repos/5s-pub-sub-with-mon-01/05.test-envs

The main issue we want to resolve with this spike is how do we manage file permissions in the bind mounts to be somewhat generalized for all host utilization scenarios

When rootful docker is used, we may use the same user id and group id on the host and in the guest, so that file permissions are the same. This involves some user translation for the containers guests. In case of rootless containers, this is not achievable, but we may use a common group and work with group level permissions and a special job (e.g. running an alpine as root sweeper that sets the ownership and permissions to the current user, seen as root in the rootless container every time there is some drift)

This spike analyzes the ramifications that derive from the use cases, the mounting and user maping scenarios and offers pros and cons of each approach, while offering consistent operational guides for each scenario.
