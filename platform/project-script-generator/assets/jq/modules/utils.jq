module {
  name: "iam-demo/utils",
  version: "0.1.0",
  description: "iam-demo JQ utility functions",
  license: "SPDX-License-Identifier: Apache-2.0 OR MIT",
};

def select_from_arg_name(argName):
  $ARGS.named."\(argName)" as $argValue |
  if $argValue == null then
    ({
      error: "arg value is null",
      argName: "\(argName)",
      argValue: "\($argValue)",
      description: "Set the proper value using '--arg \(argName) <arg-value>'",
    } |  halt_error(1))
    else . end |
  if .[$argValue] != null then
    .[$argValue]
  else
    ({
      error: "Key not found in selection",
      argName: "\(argName)",
      argValue: "\($argValue)",
      description: "Could not find key '\($argValue)' in selection.\\nSet the proper value using '--arg \(argName) <arg-value>'.",
      selected_input: .,
    } |  halt_error(1))
  end
;
