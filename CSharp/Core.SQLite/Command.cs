using Microsoft.Data.Sqlite;
using System.Collections.Generic;

namespace Business.Core.SQLite
{
	public class Command : ICommand
	{
		IReader Reader { get; set; }
		public SqliteConnection SQLiteConnection { get; set; }
		public SqliteCommand SQLiteCommand { get; set; }
		public SqliteDataReader SQLiteReader { get; set; }
		public List<Parameter> Parameters { get; set; }


		public Command() {
			SQLiteCommand = new SqliteCommand();
			Parameters = new List<Parameter>();
		}

		public string CommandText {
			get {
				return SQLiteCommand?.CommandText;
			}
			set {
				SQLiteCommand.CommandText = value;
			}
		}

		public IReader ExecuteReader() {
			MakeReady();
			SQLiteReader = SQLiteCommand.ExecuteReader();
			Reader = new Reader() { SQLiteReader = SQLiteReader };
			return Reader;
		}

		public object ExecuteScalar() {
			MakeReady();
			return SQLiteCommand.ExecuteScalar();
		}

		private void MakeReady() {
			SQLiteCommand.Connection = SQLiteConnection;
			foreach (var parameter in Parameters) {
				SQLiteCommand.Parameters.Add(new SqliteParameter(parameter.Name, parameter.Value));
			}
		}
	}
}
