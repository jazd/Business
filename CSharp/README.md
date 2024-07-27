# Configure for Visual Studio

## Get latest SQLite Business database
```
Download https://github.com/jazd/Business/releases/latest/download/business.sqlite3
Copy to CSharp/SchemaVersion/business.sqlite3
```

## Minimum application profiles
```
Copy CSharp/Core.Test/profile.json.template to CSharp/Core.Test/profile.json
Copy CSharp/SchemaVersion/profile.json.SQLite to CSharp/SchemaVersion/profile.json
```

## JetBrains Rider IDE on Linux
```shell
dnf install mono-complete dotnet-sdk-8.0 mono-devel nuget
```
