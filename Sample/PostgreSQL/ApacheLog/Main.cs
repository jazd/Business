using System;
using UAParser;  // Reference UAParser from https://github.com/ua-parser/uap-csharp.git in your project

namespace ApacheLog
{
	class MainClass
	{
		public static void Main (string[] args)
		{
			// Apache log defalt 0 5 8 9
			Int16 ipIndex = 0;
			Int16 requestIndex = 5;
			Int16 referrerIndex = 8;
			Int16 uaIndex = 9;

			// CDN args 2 9 13 14
			if (args.Length > 0) {
				switch(args.Length) {
				case 4:
					uaIndex = Int16.Parse(args[3]);
					goto case 3;
				case 3:
					referrerIndex = Int16.Parse(args[2]);
					goto case 2;
				case 2:
					requestIndex = Int16.Parse(args[1]);
					goto case 1;
				case 1:
					ipIndex = Int16.Parse(args[0]);
					break;
				}
			}

			Int16 limitIndex = Math.Max(Math.Max(Math.Max(ipIndex,requestIndex),referrerIndex),uaIndex);


			var uaParser = Parser.GetDefault();
			string recordString;
			while (!string.IsNullOrEmpty(recordString = Console.ReadLine())) {
				recordString = recordString.Trim();

				// Very simplifed parsing of log line
				var recordField = System.Text.RegularExpressions.Regex.Split(recordString, " (?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");

				if(recordField.Length <= limitIndex)
					continue;

				string userAgent;
				userAgent = recordField[uaIndex];
				userAgent = userAgent.Trim('"'); // remove enclosing quotes if they exist
				if(userAgent.Length == 0)
					continue;

				var insertLine = new System.Text.StringBuilder("SELECT AnonymousSession(");

				insertLine.Append(Field(userAgent));

				var agent = uaParser.Parse(userAgent);
				
				//insertLine.Append("\n");
				insertLine.Append(Field(agent.UserAgent.Family));
				insertLine.Append(Field(agent.UserAgent.Major));
				insertLine.Append(Field(agent.UserAgent.Minor));
				insertLine.Append(Field(agent.UserAgent.Patch));
				insertLine.Append(Field(null)); // build
				//insertLine.Append("\n");
				insertLine.Append(Field(agent.OS.Family));
				insertLine.Append(Field(agent.OS.Major));
				insertLine.Append(Field(agent.OS.Minor));
				insertLine.Append(Field(agent.OS.Patch));
				//insertLine.Append("\n");
				insertLine.Append(Field(null)); // Device brand
				insertLine.Append(Field(null)); // Device model
				insertLine.Append(Field(agent.Device.Family)); // Device family
				//insertLine.Append("\n");


				insertLine.Append(UrlValues(recordField[referrerIndex])); // referrer
				//insertLine.Append("\n");

				insertLine.Append(Field(recordField[ipIndex],false)); // IP address

				//insertLine.Append(UrlValues(recordField[requestIndex],false)); // request URL

				insertLine.Append(");");
				Console.WriteLine(insertLine.ToString());
			}
		}

		public static string UrlValues(string url, bool postSep = true, bool nullGet = false)
		{
			var values = new System.Text.StringBuilder();

			// Remove string quotes
			url = url.Trim('"');

			// Check for apache style field
			if (url.Length > 4 && url.Substring (0, 4) == "GET ") {
				url = url.Substring(4, url.Length - 4);
				int indexof = url.IndexOf(" HTTP/");
				if(indexof > 0) { // Take of the end of GET field
					url = url.Substring(0,indexof +1);
				}
				if (url [0] == '/')
					url = "http://localhost" + url; // convert to localhost for now
			}

			if (!string.IsNullOrEmpty(url) && url != "-") {
				// Be sure not to allow file based references
				url = url.Replace("file:///", "http://localhost/");
				url = url.Replace("file://", "http://");

				var urlParts = new System.Uri(url);

				values.Append(Field(urlParts.Scheme == "http" ? "0" : "1"));
				values.Append(Field(urlParts.Host));
				var path = urlParts.AbsolutePath;
				path = path.Trim ('/');
				values.Append(Field(path));

				if (!nullGet) {
					var getportion = urlParts.Query;
					if (!String.IsNullOrEmpty(getportion) && getportion [0] == '?')
						getportion = getportion.Substring(1);  // remove the '?' from the beginning

					values.Append(Field(getportion, postSep));
				} else {
					values.Append(Field(null, postSep));
				}

			} else {
				// No Referrer
				values.Append(Field(null)); // ssl
				values.Append(Field(null)); // host
				values.Append(Field(null)); // path
				values.Append(Field(null, postSep)); // get
			}

			return values.ToString();
		}

		public static string Field (string field, bool postSep = true)
		{
			if (!string.IsNullOrEmpty (field)) {
				return '\'' + field + '\'' + (postSep ? "," : "");
			} else {
				return "NULL" + (postSep ? "," : "");
			}
		}
	}
}
