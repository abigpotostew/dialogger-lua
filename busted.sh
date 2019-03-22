#!/usr/bin/env bash

busted -m="./test/?.lua;./../?.lua;./bindings/?.lua" --defer-print test/test.lua test/defold_test.lua