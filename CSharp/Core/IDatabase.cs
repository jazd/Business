using System;
namespace Core
{
    public interface IDatabase
    {
        void Connect();
        Version Version();
    }
}