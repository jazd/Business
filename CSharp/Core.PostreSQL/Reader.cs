using Npgsql;

namespace Business.Core.PostgreSQL
{
    public class Reader : IReader
    {
        public NpgsqlDataReader PostgreSQLReader { get; set; }

        public bool HasRows {
            get {
                return PostgreSQLReader.HasRows;
            }
        }

        public string GetString(int i) {
            return PostgreSQLReader.IsDBNull(i) ? null : PostgreSQLReader.GetString(i);
        }

        public void Read() {
            PostgreSQLReader.Read();
        }
    }
}
