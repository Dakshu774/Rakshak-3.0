import requests

def send_push_notification(token, message):
    url = 'https://fcm.googleapis.com/fcm/send'
    headers = {
        'Authorization': 'key=BHuESPOqWgznrYyqyJ0eGryR3RPqQbocLsOzoyikH6jE3yoRu9g6bYx1E7OyOOD5ahViQ4KfsG4A2aY1kcEolvM',
        'Content-Type': 'application/json'
    }
    data = {
        "to": token,
        "notification": {
            "title": "Emergency Alert",
            "body": message
        }
    }

    response = requests.post(url, json=data, headers=headers)
    print(response.status_code, response.json())

# Example usage
send_push_notification("recipient_device_token", "Help! I am in danger.")
