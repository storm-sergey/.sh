#!/bin/bash

find . -name "*.yml" -exec sed -i 's/\t/  /g' {} \;
