from sodapy import Socrata
import json
import boto3
import os

def main():

    # NYC uses Socrata Open Data API, with it's own Python Library for requests
    client = Socrata("data.cityofnewyork.us", "qDvyASrqcm6p4pcF2Q6dFr7PJ") # second argument is app token

    results = client.get(
        "92iy-9c3n",    # Dataset Identifier
        limit = 30000,
        where = "borough = 'MANHATTAN' AND vacant_6_30_or_date_sold = 'YES'"    # SoQL query parameter
    )

    # remove all properties without lat/long data
    filtered = [
        record for record in results
        if record.get("latitude") and record.get("longitude")
    ]

    unique_primary_business_activity_set = {item["primary_business_activity"] for item in filtered if "primary_business_activity" in item}
    print(unique_primary_business_activity_set)

    # convert set to list so it can be serialized as json
    unique_primary_business_activity_list = list(unique_primary_business_activity_set)

    # # save properties to file
    # with open("data/properties.json", "w") as file:
    #     json.dump(filtered, file, indent=2)

    # # save activities to file
    # with open("data/activities.json", "w") as file:
    #     json.dump(unique_primary_business_activity_list, file, indent=2)
    
    # set up S3 connection
    s3 = boto3.client("s3", endpoint_url = "http://localhost:4566")

    # save properties to s3 bucket
    s3.put_object(
        Bucket = os.environ["BUCKET_NAME"],
        Key = "data/properties.json",
        Body = json.dump(filtered, indent=2),
        ContentType="application/json"
    )

    # save activities to s3 bucket
    s3.put_object(
        Bucket = "web_bucket",
        Key = "data/activities.json",
        Body = json.dumps(unique_primary_business_activity_list, indent=2),
        ContentType="application/json"
    )

def lambda_handler(event, context):
    # Lambda Function starts from here
    try:
        main()
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "ETL Script Run Successfully"})
        }
    except Exception as e:
        print(f"error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }


# for local testing
if __name__ == "__main__":
    main()