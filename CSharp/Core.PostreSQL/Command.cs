using System.Collections.Generic;
using Npgsql;

namespace Business.Core.PostgreSQL
{
	public class Command : ICommand
	{
		IReader Reader { get; set; }
		public NpgsqlConnection PostgreSQLConnection { get; set; }
		public NpgsqlCommand PostgreSQLCommand { get; set; }
		public NpgsqlDataReader PostgreSQLReader { get; set; }
		public List<Parameter> Parameters { get; set; }

		public Command() {
			PostgreSQLCommand = new NpgsqlCommand();
			Parameters = new List<Parameter>();

		}

		public string CommandText {
			get {
				return PostgreSQLCommand?.CommandText;
			}
			set {
				PostgreSQLCommand.CommandText = value;
			}
		}

		public IReader ExecuteReader() {
			PostgreSQLCommand.Connection = PostgreSQLConnection;
			foreach (var parameter in Parameters) {
				PostgreSQLCommand.Parameters.Add(new NpgsqlParameter(parameter.Name, parameter.Value));
			}
			PostgreSQLReader = PostgreSQLCommand.ExecuteReader();
			Reader = new Reader() { PostgreSQLReader = PostgreSQLReader };
			return Reader;
		}

		public object ExecuteScalar() {
			PostgreSQLCommand.Connection = PostgreSQLConnection;
			foreach (var parameter in Parameters) {
				PostgreSQLCommand.Parameters.Add(new NpgsqlParameter(parameter.Name, parameter.Value));
			}
			return PostgreSQLCommand.ExecuteScalar();
		}
	}
}
