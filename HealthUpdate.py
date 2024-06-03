import json

def update_theater_health(source_data, target_data):
    # Updating TheaterHealth
    source_theater_health = source_data.get('TheaterHealth', {})
    target_theater_health = target_data.get('TheaterHealth', {})
    
    for theater_name, theater_info in target_theater_health.items():
        if theater_name in source_theater_health:
            theater_info['Health'] = source_theater_health[theater_name]['Health']

def main(source_file, target_file, output_file):
    # Load source and target JSON data
    with open(source_file, 'r') as f:
        source_data = json.load(f)
    
    with open(target_file, 'r') as f:
        target_data = json.load(f)
    
    # Update TheaterHealth and Connections
    update_theater_health(source_data, target_data)
    
    # Save the updated target data to the output file
    with open(output_file, 'w') as f:
        json.dump(target_data, f, indent=4)

if __name__ == "__main__":
    source_file = 'BurningMirage_State_server.json'
    target_file = 'BurningMirage_State.json'
    output_file = 'output.json'
    main(source_file, target_file, output_file)