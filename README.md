# Cloud SQL Performance Benchmark

This is repository accompanying blog post about benchmarking Cloud SQL -
PostgreSQL performance published at https://stepan.wtf/cloud-sql-performance/.


## Prerequisites

Binaries:
- gcloud
- terraform (v12)
- awk
- bash
- gnuplot (for charts)
- st (for charts)

Terraform code expects valid GCP credentials (`gcloud auth login`) and existing
Project ID set in `TF_VAR_project` variable.

## Usage

```bash
$ export TF_VAR_project=my-gcp-project
$ ./gcp-cloudsql-bench.sh
```

Script will create directory named like `results-2020-01-11T03-27-kgJw` by
default and all results will be saved there.

Run this from a machine with reliable internet connection, as the tests take a
while.

You can explore optional parameters, each of these can be set by setting
corresponding environemnt variable:
```
# Optional
DISABLE_COLORS="${DISABLE_COLORS:="false"}"
PGBENCH_RUN_CLIENTS="${PGBENCH_RUN_CLIENTS:="50"}"
PGBENCH_RUN_TIME="${PGBENCH_RUN_TIME:="300"}"
PGBENCH_SCALE_FACTOR="${PGBENCH_SCALE_FACTOR:="100"}"
PGBENCH_WORKER_THREADS="${PGBENCH_WORKER_THREADS:="8"}"
PRINT_PREFIX="${PRINT_PREFIX:=""}"
REQUIRED_BINARIES="${REQUIRED_BINARIES:="gcloud terraform awk gnuplot"}"
TEST_CPUS="${TEST_CPUS:="1 2 4 8 16 32 64"}"
TEST_ITERATIONS="${TEST_ITERATIONS:="5"}"
export TF_VAR_region="${TF_VAR_region:="europe-west2"}"
RESULTS_DIR="${RESULTS_DIR:=""}"
```

### Charts

Included is script `charts.sh` used to generate various charts used in the
blog-post. Script will generate chars for all directories specified in
`INPUT_DIRS` env. variable (by default all directories named `results-*` in the
current directory). Output will be be default in `charts` directory.

```
$ ./charts.sh
```

Optional variables;
```
# Optional
DISABLE_COLORS="${DISABLE_COLORS:="false"}"
TEST_CPUS="${TEST_CPUS:="1 2 4 8 16 32 64"}"
TEST_ITERATIONS="${TEST_ITERATIONS:="5"}"
OUTPUT_DIR="${OUTPUT_DIR:="charts"}"
INPUT_DIRS="$(ls -d results-*)"
```
