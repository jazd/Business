using NuoDb.Data.Client;
using System.Collections.Generic;
using System.Data.Common;

namespace Business.Core.NuoDB
{
	public class Command : ICommand
	{
		IReader Reader { get; set; }
		public List<Parameter> Parameters { get => throw new System.NotImplementedException(); set => throw new System.NotImplementedException(); }

		public NuoDbConnection NuoDBClientConnection { get; set; }
		public NuoDbCommand NuoDBClientCommand { get; set; }
		public DbDataReader NuoDBReader { get; set; }

		public Command() {
			NuoDBClientCommand = new NuoDbCommand();
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
			NuoDBClientCommand.Connection = NuoDBClientConnection;
			NuoDBReader = NuoDBClientCommand.ExecuteReader();
			Reader = new Reader() { NuoDBReader = NuoDBReader };
			return Reader;
		}
	}
}
