#!/usr/bin/env coffee

Cascade = require '../cascade'
Outlet = require '../Outlet'
Autorun = require '../Autorun'

x = new Outlet

y = new Outlet(-> 2*x.get())

