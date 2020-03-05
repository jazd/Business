using System;
namespace Business.Core
{
    public interface ICommand
    {
        string CommandText { get; set; }

        IReader ExecuteReader();
    }
}
