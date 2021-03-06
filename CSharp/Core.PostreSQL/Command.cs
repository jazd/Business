using System;
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
			Parameters = new List<Parameter>();
		}

		public string CommandText {
			get {
				return PostgreSQLCommand?.CommandText;
			}
			set {
				PostgreSQLCommand = new NpgsqlCommand() { Connection = PostgreSQLConnection };
				PostgreSQLCommand.CommandText = value;
			}
		}

		public void TransactionText(IDisposable transaction, string sql) {
			PostgreSQLCommand = new NpgsqlCommand() { Connection = PostgreSQLConnection, Transaction = (NpgsqlTransaction)transaction };
			PostgreSQLCommand.CommandText = sql;
		}

		public IReader ExecuteReader() {
			MakeReady();
			PostgreSQLReader = PostgreSQLCommand.ExecuteReader();
			Reader = new Reader() { PostgreSQLReader = PostgreSQLReader };
			return Reader;
		}

		public object ExecuteScalar() {
			MakeReady();
			return PostgreSQLCommand.ExecuteScalar();
		}


		public int ExecuteNonQuery() {
			throw new NotImplementedException();
		}

		private void MakeReady() {
			foreach (var parameter in Parameters) {
				// PostgreSQL does not support UInt64
				var value = parameter.Value;
				if (value.GetType().Equals(typeof(UInt64))) {
					value = Convert.ToInt64(value);
				}
				PostgreSQLCommand.Parameters.Add(new NpgsqlParameter(parameter.Name, value));
			}
		}
	}
}
