using NuoDb.Data.Client;
using System.Text;
using System.Linq;
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
			Parameters = new List<Parameter>();
		}

		public string CommandText {
			get {
				return NuoDBClientCommand?.CommandText;
			}
			set {
				NuoDBClientCommand = new NuoDbCommand() { Connection = NuoDBClientConnection };
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


		public int ExecuteNonQuery() {
			throw new System.NotImplementedException();
		}

		private void MakeReady() {
			if (Parameters.Count > 0) {
				// NuoDB uses ? for parameters in order, so convert SQL Command Text
				List<object> parametersInOrder = new List<object>();
				StringBuilder newSQL = new StringBuilder();

				// Convert parameter @<name> to just ? and add parameter to an ordered list
				var names = NuoDBClientCommand.CommandText.Split('@');
				newSQL.Append(names[0]);
				for (var segment = 1; segment < names.Length; segment++) {
					// replace parameter name with ?
					newSQL.Append('?');

					// remove parameter name from front of string segment
					var i = names[segment].TakeWhile(char.IsLetterOrDigit).Count();
					newSQL.Append(names[segment].Substring(i));

					// Add the value to an ordered list
					parametersInOrder.Add(Parameters.Find(n => n.Name == "@" + names[segment].Substring(0,i))?.Value);
				}
				NuoDBClientCommand.CommandText = newSQL.ToString();
				foreach (var parameterValue in parametersInOrder) {
					NuoDBClientCommand.Parameters.Add(parameterValue);
				}
			}
		}
	}
}
