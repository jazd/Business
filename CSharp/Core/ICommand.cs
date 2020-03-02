using System;
namespace Core
{
    public interface ICommand
    {
        string CommandText { get; set; }

        IReader ExecuteReader();
    }
}
