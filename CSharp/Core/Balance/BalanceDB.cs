using System;
namespace Business.Core
{
	public partial class Balance {
		public static Balance LoadFromReader(IReader reader) {
			Balance record = new Balance();
			record.Book = reader.GetInt32(0).Value;
			record.Entry = reader.GetInt32(1).Value;
			record.Account = reader.GetInt32(2).Value;
			record.NameId = reader.GetInt32(3).Value;
			record.Name = reader.GetString(4);
			record.RightSide = reader.GetBoolean(5).Value;
			record.TypeId = reader.GetInt32(6).Value;
			record.Type = reader.GetString(7);
			record.Debit = reader.GetFloat(8);
			record.Credit = reader.GetFloat(9);

			return record;
		}
	}
}
