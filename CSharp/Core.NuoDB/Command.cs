using NuoDb.Data.Client;
using System.Collections.Generic;
using System.Data.Common;

namespace Business.Core.NuoDB
{
	public class Command : ICommand
	{
		IReader Reader { get; set; }
		public List<Parameter> Parameters { get; set; }
		public NuoDbConnection NuoDBClientConnection { get; set; }
		public NuoDbCommand NuoDBClientCommand { get; set; }
		public DbDataReader NuoDBReader { get; set; }

		public Command() {
			NuoDBClientCommand = new NuoDbCommand();
			Parameters = new List<Parameter>();
		}

		public string CommandText {
			get {
				return NuoDBClientCommand?.CommandText;
			}
			set {
				NuoDBClientCommand.CommandText = value;
			}
		}

		public IReader ExecuteReader() {
			MakeReady();
			NuoDBReader = NuoDBClientCommand.ExecuteReader();
			Reader = new Reader() { NuoDBReader = NuoDBReader };
			return Reader;
		}

		public object ExecuteScalar() {
			MakeReady();
			return NuoDBClientCommand.ExecuteScalar();
		}

		private void MakeReady() {
			NuoDBClientCommand.Connection = NuoDBClientConnection;
			if (Parameters.Count > 0) {
				// NuoDB uses ? for parameters in order, so new convert SQL Command Text
				// TODO analize SQL to get actual order and repeats
				// For now us super simple and not efficient assumint parameters are in order and no repeats
				var sql = NuoDBClientCommand.CommandText;
				foreach (var parameter in Parameters) {
					sql = sql.Replace(parameter.Name, "?");
					NuoDBClientCommand.Parameters.Add(parameter.Value);
				}
				NuoDBClientCommand.CommandText = sql;
			}
		}
	}
}
