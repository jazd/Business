using System;
namespace Business.Core
{
	public partial class Individual
	{
		public IDatabase Database { get; private set; }

		public Individual(IDatabase database, UInt64? id = null) {
			Database = database;
			if(id != null)
				Load((UInt64)id);
		}

		private void Load(UInt64 id) {
			// Overwrite this object with Individual id
			Empty();
			Id = id;
			// Default to person for now
			Person = true;

			if (Database != null) {
				Database.Connect();
				Database.Connection.Open();

				Database.Command.CommandText = GetIndividualSQL;
				Database.Command.Parameters.Add(new Parameter() { Name= "@id", Value = id });
				var reader = Database.Command.ExecuteReader();
				if (reader.HasRows) {
					if (reader.Read()) {
						try {
							FullName = reader.GetString(0);
							GoesBy = reader.GetString(1);
						} catch (Exception ex) {
							// Some sort of type or data issue
							Database.Profile.Log?.Error($"reading Individual: {ex.Message}");
						}
					}
				}
				Database.Connection.Close();
			}
		}

		private const string GetIndividualSQL = @"
SELECT fullname, goesBy
FROM (
 SELECT fullname, goesBy
 FROM People
 WHERE individual = @id
 UNION
 SELECT name AS fullname, goesBy
 FROM Entities
 WHERE individual = @id
) AS Individual
LIMIT 1
";
	}
}
