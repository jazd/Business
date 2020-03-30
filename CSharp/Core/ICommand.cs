using System;
using System.Collections.Generic;

namespace Business.Core
{
	public interface ICommand
	{
		string CommandText { get; set; }
		List<Parameter> Parameters { get; set; }

		IReader ExecuteReader();
		object  ExecuteScalar();
		int     ExecuteNonQuery();
		void TransactionText(IDisposable transaction, string sql);
	}
}
