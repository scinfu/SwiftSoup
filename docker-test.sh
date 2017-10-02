#!/bin/bash
docker build --tag swiftsoup .
docker run --rm swiftsoup
