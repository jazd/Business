using System.Collections.Generic;

namespace Business.Core
{
	public interface ICommand
	{
		string CommandText { get; set; }
		List<Parameter> Parameters { get; set; }

		IReader ExecuteReader();
	}
}
