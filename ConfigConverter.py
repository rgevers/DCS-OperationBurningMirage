import json

# Read JSON data from a file
input_file = 'BurningMirage_State.json'
output_file = 'output.json'

with open(input_file, 'r') as file:
    data = json.load(file)

# Process connections and update TheaterHealth with connection types
connections_by_type = {"TRUCK": {}, "HELO": {}, "SHIP": {}, "PLANE": {}}

for connection in data["Connections"]:
    source = connection["SourceTheater"]
    dest = connection["DestinationTheater"]
    conn_type = connection["Type"]

    if source in data["TheaterHealth"]:
        if source not in connections_by_type[conn_type]:
            connections_by_type[conn_type][source] = []
        connections_by_type[conn_type][source].append(dest)

# Add the connections to TheaterHealth if they exist
for theater in data["TheaterHealth"].keys():
    for conn_type, theaters in connections_by_type.items():
        if theater in theaters:
            data["TheaterHealth"][theater][conn_type] = theaters[theater]

# Write the transformed data back to a file
with open(output_file, 'w') as file:
    json.dump(data, file, indent=2)

print(f'Transformed data written to {output_file}')