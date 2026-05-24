#!/bin/zsh

jsonshape() {
    jq '
def shape:
  if type == "string" then "..."
  elif type == "number" then 0
  elif type == "boolean" then .
  elif type == "null" then null
  elif type == "array" then
    if length > 0 then [.[0] | shape] else [] end
  elif type == "object" then
    with_entries(.value |= shape)
  else .
  end;

shape
'
}


