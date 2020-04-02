using System;
using System.Collections.Generic;

namespace Business.Core
{
	public partial class Balance
	{
		public UInt32 Book { get; set; }
		public UInt32 Entry { get; set; }
		public UInt32 Account { get; set; }
		public UInt32 NameId { get; set; }
		public String Name { get; set; }
		public Boolean RightSide { get; set; }
		public UInt32 TypeId { get; set; }
		public String Type { get; set; }
		public float? Debit { get; set; }
		public float? Credit { get; set; }

		// Virtual field
		public float Value {
			get {
				return Math.Abs((Debit ?? 0) - (Credit ?? 0));
			}
		}

		public override string ToString() {
			return $"{Book}, {Entry}, {Account}, {Name}, {Type}, {Debit}, {Credit}, {Value}";
		}

		public static float AccountTypeValue(List<Balance> records, string type) {
			float value = 0;
			foreach (var record in records) {
				if (record.Type == type)
					value += record.Value;
			}
			return value;
		}
	}
}
